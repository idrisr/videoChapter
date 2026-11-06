{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Aeson (eitherDecode)
import Fmt (fmt, prettyLn)
import Options.Applicative
import VideoChapter.Mediainfo (runMediainfo)
import VideoChapter.Model (Media)

data CliOptions = CliOptions
    { optMediaFile :: FilePath
    }

main :: IO ()
main = do
    opts <- execParser optsInfo
    input <- runMediainfo (optMediaFile opts)
    case eitherDecode input of
        Left err -> putStrLn $ "Error parsing JSON: " <> err
        Right media -> fmt . prettyLn $ (media :: Media)

optionsParser :: Parser CliOptions
optionsParser =
    CliOptions
        <$> strArgument
            ( metavar "MEDIAFILE"
                <> help "Media file to analyze with mediainfo"
            )

optsInfo :: ParserInfo CliOptions
optsInfo =
    info
        (optionsParser <**> helper)
        ( fullDesc
            <> progDesc "Extract and display video chapter information from a media file"
        )
