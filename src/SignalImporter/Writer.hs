{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module SignalImporter.Writer
  ( -- * Database Writing
    writeToDatabase
  , insertContacts
  , insertMessages
  , PostgresConfig (..)
  ) where

import Control.Applicative ((<|>))
import Control.Exception (bracket, catch, SomeException)
import Data.Aeson (Value, encode, object, (.=), toJSON)
import qualified Data.Aeson as Aeson
import qualified Data.ByteString.Lazy as BL
import Data.Int (Int64)
import Data.Maybe (fromMaybe, catMaybes)
import Data.Pool (Pool, createPool, withResource)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import Data.Time (UTCTime)
import Data.Time.Clock.POSIX (posixSecondsToUTCTime)
import Database.PostgreSQL.Simple
  ( Connection
  , Query
  , connectPostgreSQL
  , close
  , execute
  , executeMany
  , withTransaction
  )
import Database.PostgreSQL.Simple.ToField (ToField(..), Action(..))
import Database.PostgreSQL.Simple.Types (PGArray(..))
import qualified Database.PostgreSQL.Simple as PG
import SignalImporter.Types

-- | PostgreSQL connection configuration
data PostgresConfig = PostgresConfig
  { pgHost     :: Text
  , pgPort     :: Int
  , pgDatabase :: Text
  , pgUser     :: Text
  , pgPassword :: Text
  } deriving (Show, Eq)

-- | Build connection string from config
buildConnString :: PostgresConfig -> Text
buildConnString PostgresConfig{..} =
  T.concat
    [ "host=", pgHost
    , " port=", T.pack (show pgPort)
    , " dbname=", pgDatabase
    , " user=", pgUser
    , " password=", pgPassword
    ]

-- | Write conversations and messages to PostgreSQL database
writeToDatabase
  :: PostgresConfig
  -> [SignalConversation]
  -> [SignalMessage]
  -> IO (Either Text Int)
writeToDatabase config conversations messages =
  catch (bracket openConn close processData) handleError
  where
    openConn = connectPostgreSQL $ TE.encodeUtf8 $ buildConnString config

    processData conn = withTransaction conn $ do
      contactCount <- insertContacts conn conversations
      messageCount <- insertMessages conn conversations messages
      pure $ Right (contactCount + messageCount)

    handleError :: SomeException -> IO (Either Text a)
    handleError e = pure $ Left $ T.pack $ "Database write error: " ++ show e

-- | Insert contacts from conversations
insertContacts :: Connection -> [SignalConversation] -> IO Int
insertContacts conn conversations = do
  let contacts = map conversationToContact conversations
  results <- mapM (execute conn insertContactQuery) contacts
  pure $ sum $ map fromIntegral results
  where
    insertContactQuery =
      "INSERT INTO contacts \
      \(contact_id, display_name, signal_id) \
      \VALUES (?, ?, ?) \
      \ON CONFLICT (contact_id) DO UPDATE SET \
      \  display_name = EXCLUDED.display_name, \
      \  signal_id = EXCLUDED.signal_id, \
      \  updated_at = CURRENT_TIMESTAMP"

    conversationToContact conv =
      ( convId conv
      , convName conv <|> convProfileName conv
      , Just $ convId conv
      )

-- | Insert messages into database
insertMessages :: Connection -> [SignalConversation] -> [SignalMessage] -> IO Int
insertMessages conn conversations messages = do
  let unifiedMessages = catMaybes $ map (messageToUnified conversations) messages
  results <- mapM (execute conn insertMessageQuery) unifiedMessages
  pure $ sum $ map fromIntegral results
  where
    insertMessageQuery =
      "INSERT INTO messages \
      \(message_id, platform, sender, recipients, content, metadata, timestamp, received_at) \
      \VALUES (?, ?, CAST(? AS jsonb), CAST(? AS jsonb), CAST(? AS jsonb), CAST(? AS jsonb), ?, ?) \
      \ON CONFLICT (message_id) DO UPDATE SET \
      \  content = EXCLUDED.content, \
      \  metadata = EXCLUDED.metadata, \
      \  updated_at = CURRENT_TIMESTAMP"

    messageToUnified :: [SignalConversation] -> SignalMessage -> Maybe
      ( Text              -- message_id
      , Text              -- platform
      , Text              -- sender (JSON)
      , Text              -- recipients (JSON)
      , Text              -- content (JSON)
      , Text              -- metadata (JSON)
      , Maybe UTCTime     -- timestamp
      , Maybe UTCTime     -- received_at
      )
    messageToUnified convs msg = do
      conv <- findConversation convs (msgConversationId msg)
      let sender = createSenderJson conv
      let recipients = createRecipientsJson conv
      let content = createContentJson msg
      let metadata = createMetadataJson msg conv
      let timestamp = timestampToUTC (msgSentAt msg)
      let receivedAt = timestampToUTC (msgReceivedAt msg)

      pure
        ( msgId msg
        , "Signal"
        , jsonToText sender
        , jsonToText recipients
        , jsonToText content
        , jsonToText metadata
        , timestamp
        , receivedAt
        )

    findConversation convs targetId =
      case filter (\c -> convId c == targetId) convs of
        (c:_) -> Just c
        []    -> Nothing

    createSenderJson conv = object
      [ "contactId" .= convId conv
      , "displayName" .= (convName conv <|> convProfileName conv)
      , "platform" .= ("Signal" :: Text)
      ]

    createRecipientsJson conv = case convType conv of
      DirectMessage -> toJSON [object
        [ "contactId" .= convId conv
        , "displayName" .= (convName conv <|> convProfileName conv)
        ]]
      GroupChat -> toJSON $ map (\memberId -> object
        [ "contactId" .= memberId
        , "displayName" .= memberId
        ]) (convMembers conv)

    createContentJson msg = object
      [ "text" .= msgBody msg
      , "type" .= msgType msg
      , "attachments" .= toJSON (map attachmentToJson (msgAttachments msg))
      , "rawData" .= msgJson msg
      ]

    attachmentToJson att = object
      [ "contentType" .= attContentType att
      , "fileName" .= attFileName att
      , "path" .= attPath att
      , "size" .= attSize att
      , "width" .= attWidth att
      , "height" .= attHeight att
      , "caption" .= attCaption att
      ]

    createMetadataJson msg conv = object
      [ "conversationId" .= msgConversationId msg
      , "conversationName" .= (convName conv <|> convProfileName conv)
      , "conversationType" .= show (convType conv)
      , "hasAttachments" .= msgHasAttachments msg
      , "originalJson" .= msgJson msg
      ]

    timestampToUTC Nothing = Nothing
    timestampToUTC (Just millis) =
      Just $ posixSecondsToUTCTime $ fromIntegral millis / 1000

    jsonToText = TE.decodeUtf8 . BL.toStrict . encode
