{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE NamedFieldPuns #-}

module Main where

import Control.Monad (when)
import Control.Exception (try, SomeException)
import Data.Text (Text)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import Options.Applicative
import System.Exit (exitFailure, exitSuccess)
import System.IO (hPutStrLn, stderr)
import System.Environment (lookupEnv)

import Configuration.Dotenv (loadFile, defaultConfig)

import SignalImporter.Reader
import SignalImporter.Writer
import SignalImporter.Types

-- | Command-line options
data Options = Options
  { optSignalDb   :: FilePath
  , optPgHost     :: Text
  , optPgPort     :: Int
  , optPgDatabase :: Text
  , optPgUser     :: Text
  , optPgPassword :: Text
  , optVerbose    :: Bool
  , optDryRun     :: Bool
  } deriving (Show)

data Defaults = Defaults
  { defSignalDb :: FilePath
  , defPgHost :: Text
  , defPgPort :: Int
  , defPgDatabase :: Text
  , defPgUser :: Text
  , defPgPassword :: Text
  }

-- | Command-line parser with environment defaults
optionsParserWithDefaults :: Defaults -> Parser Options
optionsParserWithDefaults Defaults{..} = Options
  <$> strOption
      ( long "signal-db"
     <> short 's'
     <> metavar "PATH"
     <> help "Path to Signal Desktop database (desktop_messages.db)"
     <> value defSignalDb
     <> showDefault
      )
  <*> strOption
      ( long "pg-host"
     <> metavar "HOST"
     <> help "PostgreSQL host"
     <> value defPgHost
     <> showDefault
      )
  <*> option auto
      ( long "pg-port"
     <> metavar "PORT"
     <> help "PostgreSQL port"
     <> value defPgPort
     <> showDefault
      )
  <*> strOption
      ( long "pg-database"
     <> short 'd'
     <> metavar "DATABASE"
     <> help "PostgreSQL database name"
     <> value defPgDatabase
     <> showDefault
      )
  <*> strOption
      ( long "pg-user"
     <> short 'u'
     <> metavar "USER"
     <> help "PostgreSQL user"
     <> value defPgUser
     <> showDefault
      )
  <*> strOption
      ( long "pg-password"
     <> short 'p'
     <> metavar "PASSWORD"
     <> help "PostgreSQL password"
     <> value defPgPassword
     <> showDefault
      )
  <*> switch
      ( long "verbose"
     <> short 'v'
     <> help "Enable verbose output"
      )
  <*> switch
      ( long "dry-run"
     <> help "Read database but don't write to PostgreSQL"
      )

-- | Main program
main :: IO ()
main = do
  -- Load .env if present (ignore errors)
  _ <- try (loadFile defaultConfig) :: IO (Either SomeException ())

  -- Read environment defaults
  envDefaults <- readDefaultsFromEnv

  opts <- execParser $ info (optionsParserWithDefaults envDefaults <**> helper)
    ( fullDesc
   <> progDesc "Import Signal Desktop messages into PostgreSQL database"
   <> header "signal-importer - Import Signal messages"
    )

  runImporter opts

-- | Run the import process
runImporter :: Options -> IO ()
runImporter Options{..} = do
  when optVerbose $
    TIO.putStrLn $ "Reading Signal database from: " <> T.pack optSignalDb

  -- Read Signal Desktop database
  result <- readSignalDatabase optSignalDb
  case result of
    Left err -> do
      hPutStrLn stderr $ "Error reading Signal database: " ++ T.unpack err
      exitFailure

    Right (conversations, messages) -> do
      when optVerbose $ do
        TIO.putStrLn $ "Found " <> T.pack (show $ length conversations) <> " conversations"
        TIO.putStrLn $ "Found " <> T.pack (show $ length messages) <> " messages"

      if optDryRun
        then do
          TIO.putStrLn "Dry run - not writing to database"
          printSummary conversations messages
          exitSuccess
        else do
          when optVerbose $
            TIO.putStrLn "Writing to PostgreSQL database..."

          let pgConfig = PostgresConfig
                { pgHost = optPgHost
                , pgPort = optPgPort
                , pgDatabase = optPgDatabase
                , pgUser = optPgUser
                , pgPassword = optPgPassword
                }

          writeResult <- writeToDatabase pgConfig conversations messages
          case writeResult of
            Left err -> do
              hPutStrLn stderr $ "Error writing to database: " ++ T.unpack err
              exitFailure

            Right count -> do
              TIO.putStrLn $ "Successfully imported " <> T.pack (show count) <> " records"
              when optVerbose $
                printSummary conversations messages
              exitSuccess

-- | Print summary of imported data
printSummary :: [SignalConversation] -> [SignalMessage] -> IO ()
printSummary conversations messages = do
  TIO.putStrLn "\nSummary:"
  TIO.putStrLn $ "  Conversations: " <> T.pack (show $ length conversations)
  TIO.putStrLn $ "    Direct: " <> T.pack (show $ length directConvs)
  TIO.putStrLn $ "    Groups: " <> T.pack (show $ length groupConvs)
  TIO.putStrLn $ "  Messages: " <> T.pack (show $ length messages)
  TIO.putStrLn $ "    With attachments: " <> T.pack (show $ length messagesWithAttachments)
  where
    directConvs = filter (\c -> convType c == DirectMessage) conversations
    groupConvs = filter (\c -> convType c == GroupChat) conversations
    messagesWithAttachments = filter msgHasAttachments messages

-- | Read defaults from environment variables (with hardcoded fallbacks)
readDefaultsFromEnv :: IO Defaults
readDefaultsFromEnv = do
  mSignalDb <- lookupEnv "SIGNAL_DB"
  mPgHost <- lookupEnv "PG_HOST"
  mPgPort <- lookupEnv "PG_PORT"
  mPgDatabase <- lookupEnv "PG_DATABASE"
  mPgUser <- lookupEnv "PG_USER"
  mPgPassword <- lookupEnv "PG_PASSWORD"

  let defSignalDb = maybe "desktop_messages.db" id mSignalDb
      defPgHost = T.pack $ maybe "localhost" id mPgHost
      defPgPort = maybe 5432 read mPgPort
      defPgDatabase = T.pack $ maybe "message_unifier" id mPgDatabase
      defPgUser = T.pack $ maybe "postgres" id mPgUser
      defPgPassword = T.pack $ maybe "" id mPgPassword

  pure Defaults
    { defSignalDb
    , defPgHost
    , defPgPort
    , defPgDatabase
    , defPgUser
    , defPgPassword
    }
