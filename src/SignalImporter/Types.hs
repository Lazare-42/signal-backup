{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module SignalImporter.Types
  ( -- * Signal Types
    SignalConversation (..)
  , SignalMessage (..)
  , SignalAttachment (..)
  , ConversationType (..)

    -- * Unified Types
  , UnifiedMessage (..)
  , UnifiedContact (..)
  , MessageContent (..)
  , AttachmentInfo (..)
  ) where

import Data.Aeson (FromJSON, ToJSON, Value)
import Data.Text (Text)
import Data.Time (UTCTime)
import Data.Int (Int64)
import GHC.Generics (Generic)

-- | Signal conversation type
data ConversationType
  = DirectMessage
  | GroupChat
  deriving (Show, Eq, Generic)

instance ToJSON ConversationType
instance FromJSON ConversationType

-- | Signal conversation from desktop database
data SignalConversation = SignalConversation
  { convId          :: Text
  , convName        :: Maybe Text
  , convProfileName :: Maybe Text
  , convType        :: ConversationType
  , convMembers     :: [Text]  -- List of member IDs
  , convJson        :: Maybe Value  -- Raw JSON from database
  } deriving (Show, Eq, Generic)

instance ToJSON SignalConversation
instance FromJSON SignalConversation

-- | Signal attachment
data SignalAttachment = SignalAttachment
  { attContentType :: Maybe Text
  , attFileName    :: Maybe Text
  , attPath        :: Maybe Text
  , attSize        :: Maybe Int64
  , attWidth       :: Maybe Int
  , attHeight      :: Maybe Int
  , attCaption     :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON SignalAttachment
instance FromJSON SignalAttachment

-- | Signal message from desktop database
data SignalMessage = SignalMessage
  { msgId             :: Text
  , msgConversationId :: Text
  , msgBody           :: Maybe Text
  , msgType           :: Maybe Text
  , msgSentAt         :: Maybe Int64  -- Unix timestamp milliseconds
  , msgReceivedAt     :: Maybe Int64  -- Unix timestamp milliseconds
  , msgHasAttachments :: Bool
  , msgAttachments    :: [SignalAttachment]
  , msgJson           :: Maybe Value  -- Raw JSON metadata
  } deriving (Show, Eq, Generic)

instance ToJSON SignalMessage
instance FromJSON SignalMessage

-- | Attachment information for unified schema
data AttachmentInfo = AttachmentInfo
  { attInfoContentType :: Text
  , attInfoFileName    :: Text
  , attInfoSize        :: Int64
  , attInfoPath        :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON AttachmentInfo
instance FromJSON AttachmentInfo

-- | Message content for unified schema
data MessageContent = MessageContent
  { contentText        :: Maybe Text
  , contentAttachments :: [AttachmentInfo]
  , contentRawData     :: Value  -- Original Signal JSON
  } deriving (Show, Eq, Generic)

instance ToJSON MessageContent
instance FromJSON MessageContent

-- | Unified contact for database
data UnifiedContact = UnifiedContact
  { contactId          :: Text
  , contactDisplayName :: Maybe Text
  , contactPhoneNumber :: Maybe Text
  , contactEmail       :: Maybe Text
  , contactDiscordId   :: Maybe Text
  , contactTelegramId  :: Maybe Text
  , contactSignalId    :: Maybe Text
  , contactWhatsappId  :: Maybe Text
  , contactAvatarUrl   :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON UnifiedContact
instance FromJSON UnifiedContact

-- | Unified message for database
data UnifiedMessage = UnifiedMessage
  { umMessageId   :: Text
  , umPlatform    :: Text  -- "Signal"
  , umSender      :: Value  -- JSONB with sender info
  , umRecipients  :: Value  -- JSONB with recipient info
  , umContent     :: Value  -- JSONB with message content
  , umMetadata    :: Value  -- JSONB with platform-specific metadata
  , umTimestamp   :: UTCTime
  , umReceivedAt  :: Maybe UTCTime
  } deriving (Show, Eq, Generic)

instance ToJSON UnifiedMessage
instance FromJSON UnifiedMessage
