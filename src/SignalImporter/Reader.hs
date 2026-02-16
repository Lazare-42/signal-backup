{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module SignalImporter.Reader
  ( -- * Database Reading
    readSignalDatabase
  , readConversations
  , readMessages
  , readAttachments
  ) where

import Control.Exception (bracket, catch, SomeException)
import Data.Aeson (Value, decode)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as BL
import Data.Maybe (fromMaybe, mapMaybe)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Database.SQLite.Simple
  ( Connection
  , Query
  , open
  , close
  , query
  , query_
  , Only(..)
  )
import Database.SQLite.Simple.FromRow (FromRow(..), field)
import SignalImporter.Types

-- | Row type for conversation query
data ConversationRow = ConversationRow
  { crId          :: Text
  , crName        :: Maybe Text
  , crProfileName :: Maybe Text
  , crType        :: Text
  , crMembers     :: Maybe Text
  , crJson        :: Maybe Text
  } deriving (Show)

instance FromRow ConversationRow where
  fromRow = ConversationRow
    <$> field  -- id
    <*> field  -- name
    <*> field  -- profileName
    <*> field  -- type
    <*> field  -- members
    <*> field  -- json

-- | Row type for message query
data MessageRow = MessageRow
  { mrId             :: Text
  , mrConversationId :: Text
  , mrBody           :: Maybe Text
  , mrType           :: Maybe Text
  , mrSentAt         :: Maybe Int
  , mrReceivedAt     :: Maybe Int
  , mrHasAttachments :: Int
  , mrJson           :: Maybe Text
  } deriving (Show)

instance FromRow MessageRow where
  fromRow = MessageRow
    <$> field  -- id
    <*> field  -- conversationId
    <*> field  -- body
    <*> field  -- type
    <*> field  -- sent_at
    <*> field  -- received_at
    <*> field  -- hasAttachments (0 or 1)
    <*> field  -- json

-- | Row type for attachment query
data AttachmentRow = AttachmentRow
  { arContentType :: Maybe Text
  , arFileName    :: Maybe Text
  , arPath        :: Maybe Text
  , arSize        :: Maybe Int
  , arWidth       :: Maybe Int
  , arHeight      :: Maybe Int
  , arCaption     :: Maybe Text
  } deriving (Show)

instance FromRow AttachmentRow where
  fromRow = AttachmentRow
    <$> field  -- contentType
    <*> field  -- fileName
    <*> field  -- path
    <*> field  -- size
    <*> field  -- width
    <*> field  -- height
    <*> field  -- caption

-- | Read all data from Signal Desktop database
readSignalDatabase :: FilePath -> IO (Either Text ([SignalConversation], [SignalMessage]))
readSignalDatabase dbPath =
  catch (bracket (open dbPath) close processDb) handleError
  where
    processDb conn = do
      conversations <- readConversations conn
      messages <- readMessages conn
      pure $ Right (conversations, messages)

    handleError :: SomeException -> IO (Either Text a)
    handleError e = pure $ Left $ T.pack $ "Database error: " ++ show e

-- | Read all conversations from database
readConversations :: Connection -> IO [SignalConversation]
readConversations conn = do
  hasTable <- tableExists conn "conversations"
  if not hasTable
    then pure []
    else do
      rows <- query_ conn conversationQuery :: IO [ConversationRow]
      pure $ map rowToConversation rows
  where
    conversationQuery =
      "SELECT id, name, profileName, type, members, json FROM conversations"

    rowToConversation ConversationRow{..} =
      SignalConversation
        { convId = crId
        , convName = crName
        , convProfileName = crProfileName
        , convType = if crType == "group" then GroupChat else DirectMessage
        , convMembers = parseMembers crMembers
        , convJson = parseJson crJson
        }

    parseMembers Nothing = []
    parseMembers (Just txt) = T.words txt

    parseJson Nothing = Nothing
    parseJson (Just txt) =
      decode (BL.fromStrict $ TE.encodeUtf8 txt) :: Maybe Value

-- | Read all messages from database
readMessages :: Connection -> IO [SignalMessage]
readMessages conn = do
  hasTable <- tableExists conn "messages"
  if not hasTable
    then pure []
    else do
      rows <- query_ conn messageQuery :: IO [MessageRow]
      mapM enrichMessage rows
  where
    messageQuery =
      "SELECT id, conversationId, body, type, sent_at, received_at, \
      \hasAttachments, json FROM messages ORDER BY sent_at"

    enrichMessage row = do
      attachments <- if mrHasAttachments row > 0
                     then readAttachments conn (mrId row)
                     else pure []
      pure $ rowToMessage row attachments

    rowToMessage MessageRow{..} attachments =
      SignalMessage
        { msgId = mrId
        , msgConversationId = mrConversationId
        , msgBody = mrBody
        , msgType = mrType
        , msgSentAt = fmap fromIntegral mrSentAt
        , msgReceivedAt = fmap fromIntegral mrReceivedAt
        , msgHasAttachments = mrHasAttachments > 0
        , msgAttachments = attachments
        , msgJson = case mrJson of
            Nothing -> Nothing
            Just txt -> decode (BL.fromStrict $ TE.encodeUtf8 txt)
        }

-- | Read attachments for a specific message
readAttachments :: Connection -> Text -> IO [SignalAttachment]
readAttachments conn messageId = do
  hasTable <- tableExists conn "message_attachments"
  if not hasTable
    then pure []
    else do
      rows <- query conn attachmentQuery (Only messageId) :: IO [AttachmentRow]
      pure $ map rowToAttachment rows
  where
    attachmentQuery =
      "SELECT contentType, fileName, path, size, width, height, caption \
      \FROM message_attachments \
      \WHERE messageId = ? AND attachmentType = 'attachment' \
      \ORDER BY orderInMessage"

    rowToAttachment AttachmentRow{..} =
      SignalAttachment
        { attContentType = arContentType
        , attFileName = arFileName
        , attPath = arPath
        , attSize = fmap fromIntegral arSize
        , attWidth = arWidth
        , attHeight = arHeight
        , attCaption = arCaption
        }

-- | Check if a given table exists in the SQLite database
tableExists :: Connection -> Text -> IO Bool
tableExists conn tableName = do
  let q = "SELECT name FROM sqlite_master WHERE type='table' AND name = ?"
  names <- query conn q (Only tableName) :: IO [Only Text]
  pure (not (null names))
