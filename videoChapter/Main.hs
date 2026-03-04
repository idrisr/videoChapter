{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad (forM)
import Data.Aeson (eitherDecode)
import Data.Char (isSpace)
import Data.List (sortOn)
import Data.Maybe (catMaybes)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.IO as TextIO
import Data.Time.Clock (NominalDiffTime)
import Fmt (fmt, prettyLn)
import Options.Applicative
import System.Directory (doesFileExist)
import System.Environment (lookupEnv)
import System.Exit (die)
import System.FilePath (replaceExtension)
import VideoChapter.Mediainfo (runMediainfo)
import VideoChapter.Model
    ( Chapter
    , Media
    , chapterTime
    , chapterTitle
    , formatTimeText
    , mediaChapters
    )
import VideoChapter.OpenAI (ChatMessage (..), OpenAIConfig (..), chatCompletion)
import VideoChapter.Srt (SrtEntry (..), parseSrtEntries)

data CliOptions = CliOptions
    { optMediaFile :: FilePath
    , optSrtFile :: Maybe FilePath
    , optSummarize :: Bool
    }

data ChapterInfo = ChapterInfo
    { chapterInfoTitle :: Text
    , chapterInfoStart :: NominalDiffTime
    }

main :: IO ()
main = do
    opts <- execParser optsInfo
    input <- runMediainfo (optMediaFile opts)
    case eitherDecode input of
        Left err -> putStrLn $ "Error parsing JSON: " <> err
        Right media ->
            if optSummarize opts
                then summarizeChapters opts media
                else fmt . prettyLn $ (media :: Media)

summarizeChapters :: CliOptions -> Media -> IO ()
summarizeChapters opts media = do
    apiKey <- requireOpenAIKey
    srtPath <- resolveSrtPath (optMediaFile opts) (optSrtFile opts)
    srtExists <- doesFileExist srtPath
    if not srtExists
        then die $ "SRT file not found: " <> srtPath
        else pure ()
    srtContents <- TextIO.readFile srtPath
    let srtEntries = parseSrtEntries srtContents
    if null srtEntries
        then die "No SRT entries parsed"
        else pure ()
    let chapterInfos = sortOn chapterInfoStart . catMaybes $ map toChapterInfo (mediaChapters media)
    if null chapterInfos
        then die "No chapters found in media metadata"
        else pure ()
    let transcriptEnd = maximum (map srtEnd srtEntries)
        chapterWindows = zip chapterInfos (map chapterInfoStart (drop 1 chapterInfos) <> [transcriptEnd])
        config = OpenAIConfig apiKey "gpt-4o-mini"
    summaries <-
        forM chapterWindows $ \(chapterInfo, windowEnd) -> do
            let transcriptSlice = buildTranscriptSlice srtEntries (chapterInfoStart chapterInfo) (Just windowEnd)
                duration = max 0 (windowEnd - chapterInfoStart chapterInfo)
            if Text.null transcriptSlice
                then pure (chapterInfoStart chapterInfo, "no transcript text available")
                else do
                    summary <-
                        summarizeSlice config chapterInfo duration transcriptSlice
                    pure (chapterInfoStart chapterInfo, summary)
    mapM_ (TextIO.putStrLn . formatSummaryLine) summaries

summarizeSlice :: OpenAIConfig -> ChapterInfo -> NominalDiffTime -> Text -> IO Text
summarizeSlice config chapterInfo duration transcriptSlice = do
    let targetWords = targetWordCount duration
        systemPrompt =
            "Write one punchy insight (a nugget) distilled from the transcript slice. "
                <> "Avoid bland phrasing like 'focuses on', 'discussion', 'talks about', 'this section'. "
                <> "Use lowercase, no quotes, no timestamps, no chapter titles. "
                <> "Target about "
                <> Text.pack (show targetWords)
                <> " words."
        userPrompt =
            Text.unlines
                [ "Transcript slice:"
                , trimTranscript 12000 transcriptSlice
                , ""
                , "Chapter start: " <> formatTimeText (chapterInfoStart chapterInfo)
                ]
        messages =
            [ ChatMessage "system" systemPrompt
            , ChatMessage "user" userPrompt
            ]
    raw <- chatCompletion config messages
    pure (normalizeSummary raw)

buildTranscriptSlice :: [SrtEntry] -> NominalDiffTime -> Maybe NominalDiffTime -> Text
buildTranscriptSlice entries startTime nextStart =
    Text.unwords . map srtText $ filter withinWindow entries
  where
    withinWindow entry =
        srtEnd entry > startTime
            && maybe True (srtStart entry <) nextStart

formatSummaryLine :: (NominalDiffTime, Text) -> Text
formatSummaryLine (startTime, summary) =
    "- " <> Text.justifyLeft 10 ' ' (formatTimeText startTime) <> summary

trimTranscript :: Int -> Text -> Text
trimTranscript maxChars text
    | Text.length text <= maxChars = text
    | otherwise = Text.take maxChars text <> " [truncated]"

normalizeSummary :: Text -> Text
normalizeSummary = cleanSpaces . dropTrailingPunct . dropQuotes . Text.toLower . Text.strip
  where
    cleanSpaces = Text.unwords . Text.words
    dropQuotes = Text.dropAround (\c -> c == '"' || c == '\'')
    dropTrailingPunct = Text.dropWhileEnd (\c -> isSpace c || c == '.' || c == ':' || c == ';' || c == ',')

targetWordCount :: NominalDiffTime -> Int
targetWordCount duration = clamp 8 30 (round (durationMinutes * 0.8) + 8)
  where
    durationMinutes :: Double
    durationMinutes = realToFrac duration / 60

clamp :: Ord a => a -> a -> a -> a
clamp minValue maxValue rawValue = max minValue (min maxValue rawValue)

toChapterInfo :: Chapter -> Maybe ChapterInfo
toChapterInfo chapter = do
    startTime <- chapterTime chapter
    pure $ ChapterInfo (chapterTitle chapter) startTime

resolveSrtPath :: FilePath -> Maybe FilePath -> IO FilePath
resolveSrtPath mediaFile overridePath =
    pure $
        case overridePath of
            Just path -> path
            Nothing -> replaceExtension mediaFile ".en.srt"

requireOpenAIKey :: IO String
requireOpenAIKey = do
    apiKey <- lookupEnv "OPENAI_API_KEY"
    case apiKey of
        Just key | not (null key) -> pure key
        _ -> die "OPENAI_API_KEY is not set"

optionsParser :: Parser CliOptions
optionsParser =
    CliOptions
        <$> strArgument
            ( metavar "MEDIAFILE"
                <> help "Media file to analyze with mediainfo"
            )
        <*> optional
            ( strOption
                ( long "srt"
                    <> metavar "SRTFILE"
                    <> help "Path to SRT file (default: MEDIAFILE.en.srt)"
                )
            )
        <*> switch
            ( long "summarize"
                <> short 's'
                <> help "Summarize chapters using the SRT transcript and OpenAI"
            )

optsInfo :: ParserInfo CliOptions
optsInfo =
    info
        (optionsParser <**> helper)
        ( fullDesc
            <> progDesc "Extract and display video chapter information from a media file"
        )
