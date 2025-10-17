{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module MessageUnifier.Config
  ( Config (..)
  , loadConfig
  , DatabaseConfig (..)
  , ServerConfig (..)
  ) where

import Control.Applicative ((<|>))
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import System.Envy (FromEnv, fromEnv, env, envMaybe, decodeEnv)
import qualified System.Envy
import Text.Read (readMaybe)

-- | Server configuration
data ServerConfig = ServerConfig
  { serverHost :: Text
  , serverPort :: Int
  } deriving (Show, Eq, Generic)

instance FromEnv ServerConfig where
  fromEnv _ = ServerConfig
    <$> (envMaybe "CORE_API_HOST" >>= \m -> pure $ maybe "0.0.0.0" id m)
    <*> (envMaybe "CORE_API_PORT" >>= \m -> pure $ maybe 8080 id m)

-- | Database configuration
data DatabaseConfig = DatabaseConfig
  { databaseUrl :: Text
  } deriving (Show, Eq, Generic)

instance FromEnv DatabaseConfig where
  fromEnv _ = DatabaseConfig
    <$> env "DATABASE_URL"

-- | Application configuration
data Config = Config
  { serverConfig   :: ServerConfig
  , databaseConfig :: DatabaseConfig
  , logLevel       :: Text
  , apiSecretKey   :: Text
  } deriving (Show, Eq, Generic)

instance FromEnv Config where
  fromEnv _ = Config
    <$> fromEnv Nothing
    <*> fromEnv Nothing
    <*> (envMaybe "LOG_LEVEL" >>= \m -> pure $ maybe "info" id m)
    <*> env "API_SECRET_KEY"

-- | Load configuration from environment variables
loadConfig :: IO (Either String Config)
loadConfig = System.Envy.decodeEnv
