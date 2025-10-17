{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}

module MessageUnifier.Utils
  ( -- * ID Generation
    generateId
  , generateMessageId

    -- * Validation
  , isValidEmail
  , isValidPhoneNumber
  , validateContact

    -- * Text Utilities
  , normalizePhoneNumber
  , sanitizeText

    -- * Time Utilities
  , getCurrentTime
  , formatTimestamp
  ) where

import Data.Char (isDigit)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime, getCurrentTime, formatTime, defaultTimeLocale)
import Data.UUID (UUID)
import qualified Data.UUID.V4 as UUID
import MessageUnifier.Core (Contact(..), ContactIdentifiers(..))

-- | Generate a random UUID
generateId :: IO UUID
generateId = UUID.nextRandom

-- | Generate a message ID with platform prefix
generateMessageId :: Text -> IO Text
generateMessageId platform = do
  uuid <- generateId
  pure $ platform <> "-" <> T.pack (show uuid)

-- | Validate email format (basic validation)
isValidEmail :: Text -> Bool
isValidEmail email =
  let parts = T.splitOn "@" email
   in case parts of
        [localPart, domain] ->
          T.length localPart > 0
            && T.length domain > 0
            && T.any (== '.') domain
            && not (T.null $ T.dropWhileEnd (== '.') domain)
        _ -> False

-- | Validate phone number format (basic validation)
isValidPhoneNumber :: Text -> Bool
isValidPhoneNumber phone =
  let cleaned = T.filter (\c -> isDigit c || c == '+') phone
   in T.length cleaned >= 10 && T.length cleaned <= 15

-- | Normalize phone number to E.164 format
normalizePhoneNumber :: Text -> Text
normalizePhoneNumber phone =
  let cleaned = T.filter (\c -> isDigit c || c == '+') phone
   in if T.head cleaned == '+'
        then cleaned
        else "+" <> cleaned

-- | Validate contact has at least one identifier
validateContact :: Contact -> Either Text Contact
validateContact contact =
  let ids = identifiers contact
   in if hasAnyIdentifier ids
        then Right contact
        else Left "Contact must have at least one identifier"
  where
    hasAnyIdentifier ContactIdentifiers{..} =
      or [ isJust phoneNumber
         , isJust email
         , isJust discordId
         , isJust telegramId
         , isJust signalId
         , isJust whatsappId
         ]
    isJust (Just _) = True
    isJust Nothing = False

-- | Sanitize text content (remove control characters)
sanitizeText :: Text -> Text
sanitizeText = T.filter (not . isControl)
  where
    isControl c = c < ' ' && c /= '\n' && c /= '\t' && c /= '\r'

-- | Format timestamp in ISO8601 format
formatTimestamp :: UTCTime -> Text
formatTimestamp time =
  T.pack $ formatTime defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ" time
