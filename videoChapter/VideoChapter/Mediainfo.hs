module VideoChapter.Mediainfo (runMediainfo) where

import qualified Data.ByteString.Lazy as BL
import Data.Text (pack)
import Data.Text.Encoding (encodeUtf8)
import System.Exit (ExitCode (ExitFailure, ExitSuccess), die)
import System.Process (readProcessWithExitCode)

runMediainfo :: FilePath -> IO BL.ByteString
runMediainfo mediaPath = do
    (exitCode, stdoutText, stderrText) <-
        readProcessWithExitCode "mediainfo" ["--output=JSON", mediaPath] ""
    case exitCode of
        ExitSuccess -> pure . BL.fromStrict . encodeUtf8 . pack $ stdoutText
        ExitFailure code ->
            die $
                "mediainfo failed with exit code "
                    <> show code
                    <> ": "
                    <> if null stderrText then stdoutText else stderrText
