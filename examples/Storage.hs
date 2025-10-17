{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DisambiguateRecordFields #-}
{-# LANGUAGE DeriveGeneric #-}

module MessageUnifier.Storage
  ( -- * Storage Operations
    StorageBackend (..)
  , MessageQuery (..)
  , initStorage
  , closeStorage

    -- * PostgreSQL Implementation
  , PostgresStorage
  , createPostgresStorage
  ) where

import Control.Exception (bracket)
import Data.Aeson (encode, decode, FromJSON, ToJSON)
import Data.Pool (Pool, createPool, withResource)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.Encoding as TE
import qualified Data.ByteString.Lazy as BL
import Data.Time (UTCTime)
import GHC.Generics (Generic)
import Database.PostgreSQL.Simple
  ( Connection
  , Query
  , connectPostgreSQL
  , close
  , query
  , query_
  , execute
  , execute_
  , executeMany
  , Only (..)
  )
import qualified Database.PostgreSQL.Simple as PG
import MessageUnifier.Core
import qualified MessageUnifier.Core as Core

-- | Query parameters for searching messages
data MessageQuery = MessageQuery
  { queryPlatform  :: Maybe Platform
  , querySender    :: Maybe Text
  , queryRecipient :: Maybe Text
  , queryStartTime :: Maybe UTCTime
  , queryEndTime   :: Maybe UTCTime
  , queryTags      :: [Text]
  , queryLimit     :: Int
  , queryOffset    :: Int
  } deriving (Show, Eq, Generic)

instance ToJSON MessageQuery
instance FromJSON MessageQuery

-- | Storage backend interface
data StorageBackend = StorageBackend
  { storeMessage    :: UnifiedMessage -> IO (Either Text ())
  , getMessage      :: Text -> IO (Maybe UnifiedMessage)
  , queryMessages   :: MessageQuery -> IO [UnifiedMessage]
  , updateMessage   :: Text -> UnifiedMessage -> IO (Either Text ())
  , deleteMessage   :: Text -> IO (Either Text ())
  , healthCheck     :: IO Bool
  }

-- | PostgreSQL storage implementation
newtype PostgresStorage = PostgresStorage
  { connectionPool :: Pool Connection
  }

-- | Create a PostgreSQL storage backend
createPostgresStorage :: Text -> IO PostgresStorage
createPostgresStorage connStr = do
  pool <- createPool
    (connectPostgreSQL $ TE.encodeUtf8 connStr)
    close
    1      -- stripes
    60     -- idle time (seconds)
    10     -- max connections per stripe
  pure $ PostgresStorage pool

-- | Initialize storage backend
initStorage :: Text -> IO (Either Text StorageBackend)
initStorage connStr = do
  storage <- createPostgresStorage connStr
  pure $ Right $ postgresBackend storage

-- | Close storage backend
closeStorage :: StorageBackend -> IO ()
closeStorage _ = pure ()  -- Pool cleanup happens automatically

-- | Create storage backend from PostgreSQL storage
postgresBackend :: PostgresStorage -> StorageBackend
postgresBackend storage = StorageBackend
  { storeMessage = storeMessagePG storage
  , getMessage = getMessagePG storage
  , queryMessages = queryMessagesPG storage
  , updateMessage = updateMessagePG storage
  , deleteMessage = deleteMessagePG storage
  , healthCheck = healthCheckPG storage
  }

-- | Store a message in PostgreSQL
storeMessagePG :: PostgresStorage -> UnifiedMessage -> IO (Either Text ())
storeMessagePG PostgresStorage{..} msg = do
  result <- withResource connectionPool $ \conn -> do
    execute conn insertQuery
      ( Core.messageId msg
      , show (Core.platform msg)
      , encode (Core.sender msg)
      , encode (Core.recipients msg)
      , encode (Core.content msg)
      , encode (Core.metadata msg)
      , Core.timestamp msg
      , Core.receivedAt msg
      )
  if result == 1
    then pure $ Right ()
    else pure $ Left "Failed to insert message"
  where
    insertQuery = "INSERT INTO messages \
                  \(message_id, platform, sender, recipients, content, metadata, timestamp, received_at) \
                  \VALUES (?, ?, ?, ?, ?, ?, ?, ?)"

-- | Get a message by ID from PostgreSQL
getMessagePG :: PostgresStorage -> Text -> IO (Maybe UnifiedMessage)
getMessagePG PostgresStorage{..} msgId = do
  results <- withResource connectionPool $ \conn ->
    query conn selectQuery (Only msgId)
  case results of
    [(msgIdDb, platformStr, senderJson, recipientsJson, contentJson, metadataJson, ts, recvAt)] ->
      pure $ buildMessage msgIdDb platformStr senderJson recipientsJson contentJson metadataJson ts recvAt
    _ -> pure Nothing
  where
    selectQuery = "SELECT message_id, platform, sender, recipients, content, metadata, timestamp, received_at \
                  \FROM messages WHERE message_id = ?"

-- | Query messages from PostgreSQL
queryMessagesPG :: PostgresStorage -> MessageQuery -> IO [UnifiedMessage]
queryMessagesPG PostgresStorage{..} MessageQuery{..} = do
  results <- withResource connectionPool $ \conn ->
    query conn selectQuery ()
  pure $ map parseMessage results
  where
    selectQuery = "SELECT message_id, platform, sender, recipients, content, metadata, timestamp, received_at \
                  \FROM messages \
                  \ORDER BY timestamp DESC \
                  \LIMIT ? OFFSET ?"
    parseMessage (msgId, platformStr, senderJson, recipientsJson, contentJson, metadataJson, ts, recvAt) =
      case buildMessage msgId platformStr senderJson recipientsJson contentJson metadataJson ts recvAt of
        Just msg -> msg
        Nothing -> error "Failed to parse message from database"

-- | Update a message in PostgreSQL
updateMessagePG :: PostgresStorage -> Text -> UnifiedMessage -> IO (Either Text ())
updateMessagePG PostgresStorage{..} msgId msg = do
  result <- withResource connectionPool $ \conn ->
    execute conn updateQuery
      ( encode (sender msg)
      , encode (recipients msg)
      , encode (content msg)
      , encode (metadata msg)
      , msgId
      )
  if result == 1
    then pure $ Right ()
    else pure $ Left "Message not found"
  where
    updateQuery = "UPDATE messages SET sender = ?, recipients = ?, content = ?, metadata = ? \
                  \WHERE message_id = ?"

-- | Delete a message from PostgreSQL
deleteMessagePG :: PostgresStorage -> Text -> IO (Either Text ())
deleteMessagePG PostgresStorage{..} msgId = do
  result <- withResource connectionPool $ \conn ->
    execute conn deleteQuery (Only msgId)
  if result == 1
    then pure $ Right ()
    else pure $ Left "Message not found"
  where
    deleteQuery = "DELETE FROM messages WHERE message_id = ?"

-- | Health check for PostgreSQL
healthCheckPG :: PostgresStorage -> IO Bool
healthCheckPG PostgresStorage{..} = do
  result <- withResource connectionPool $ \conn ->
    query_ conn "SELECT 1" :: IO [Only Int]
  pure $ not (null result)

-- | Helper to build UnifiedMessage from database row
buildMessage :: Text -> Text -> Text -> Text -> Text -> Text -> UTCTime -> Maybe UTCTime -> Maybe UnifiedMessage
buildMessage msgId platformStr senderJson recipientsJson contentJson metadataJson ts recvAt = do
  plt <- parsePlatform platformStr
  sndr <- decode (BL.fromStrict $ TE.encodeUtf8 senderJson)
  rcpts <- decode (BL.fromStrict $ TE.encodeUtf8 recipientsJson)
  cnt <- decode (BL.fromStrict $ TE.encodeUtf8 contentJson)
  meta <- decode (BL.fromStrict $ TE.encodeUtf8 metadataJson)
  pure $ UnifiedMessage msgId plt sndr rcpts cnt meta ts recvAt
  where
    parsePlatform "Email" = Just Email
    parsePlatform "SMS" = Just SMS
    parsePlatform "WhatsApp" = Just WhatsApp
    parsePlatform "Discord" = Just Discord
    parsePlatform "Telegram" = Just Telegram
    parsePlatform "Signal" = Just Signal
    parsePlatform "Voice" = Just Voice
    parsePlatform _ = Nothing
