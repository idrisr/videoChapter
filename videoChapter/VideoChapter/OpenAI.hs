{-# LANGUAGE OverloadedStrings #-}

module VideoChapter.OpenAI
    ( ChatMessage (..)
    , OpenAIConfig (..)
    , chatCompletion
    )
where

import Data.Aeson (FromJSON (..), ToJSON (..), eitherDecode, (.:), (.=))
import qualified Data.ByteString.Lazy as BL
import qualified Data.Aeson as Aeson
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding
import Network.HTTP.Client
    ( RequestBody (RequestBodyLBS)
    , Response
    , httpLbs
    , method
    , newManager
    , parseRequest
    , requestBody
    , requestHeaders
    , responseBody
    , responseStatus
    )
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Status (statusCode)
import System.Exit (die)

data OpenAIConfig = OpenAIConfig
    { openAIApiKey :: String
    , openAIModel :: Text
    }

data ChatMessage = ChatMessage
    { chatRole :: Text
    , chatContent :: Text
    }

instance ToJSON ChatMessage where
    toJSON (ChatMessage role content) =
        Aeson.object
            [ "role" .= role
            , "content" .= content
            ]

data ChatRequest = ChatRequest
    { chatModel :: Text
    , chatMessages :: [ChatMessage]
    , chatTemperature :: Double
    , chatMaxTokens :: Int
    }

instance ToJSON ChatRequest where
    toJSON (ChatRequest model messages temperature maxTokens) =
        Aeson.object
            [ "model" .= model
            , "messages" .= messages
            , "temperature" .= temperature
            , "max_tokens" .= maxTokens
            ]

data ChatResponse = ChatResponse
    { chatChoices :: [ChatChoice]
    }

data ChatChoice = ChatChoice
    { chatMessage :: ChatResponseMessage
    }

data ChatResponseMessage = ChatResponseMessage
    { chatResponseContent :: Text
    }

instance FromJSON ChatResponse where
    parseJSON = Aeson.withObject "ChatResponse" $ \obj -> do
        choices <- obj .: "choices"
        pure $ ChatResponse choices

instance FromJSON ChatChoice where
    parseJSON = Aeson.withObject "ChatChoice" $ \obj -> do
        message <- obj .: "message"
        pure $ ChatChoice message

instance FromJSON ChatResponseMessage where
    parseJSON = Aeson.withObject "ChatResponseMessage" $ \obj -> do
        content <- obj .: "content"
        pure $ ChatResponseMessage content

chatCompletion :: OpenAIConfig -> [ChatMessage] -> IO Text
chatCompletion config messages = do
    manager <- newManager tlsManagerSettings
    baseRequest <- parseRequest "https://api.openai.com/v1/chat/completions"
    let body =
            ChatRequest
                { chatModel = openAIModel config
                , chatMessages = messages
                , chatTemperature = 0.3
                , chatMaxTokens = 64
                }
        request =
            baseRequest
                { method = "POST"
                , requestBody = RequestBodyLBS (Aeson.encode body)
                , requestHeaders =
                    [ ("Authorization", TextEncoding.encodeUtf8 . Text.pack $ "Bearer " <> openAIApiKey config)
                    , ("Content-Type", "application/json")
                    ]
                }
    response <- httpLbs request manager
    let status = statusCode (responseStatus response)
    if status < 200 || status >= 300
        then die $ "OpenAI request failed with status " <> show status
        else parseResponse response

parseResponse :: Response BL.ByteString -> IO Text
parseResponse response =
    case eitherDecode (responseBody response) of
        Left err -> die $ "OpenAI response parsing failed: " <> err
        Right (ChatResponse choices) ->
            case choices of
                (ChatChoice (ChatResponseMessage content) : _) -> pure content
                _ -> die "OpenAI response contained no choices"
