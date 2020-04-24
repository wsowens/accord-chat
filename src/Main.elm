port module Main exposing (main)

import Browser
import Html exposing (div, text)
import Html.Attributes as Attr exposing (id, class)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Regex

-- MAIN
main = 
  Browser.document
  { init = init
  , view = view
  , update = update
  , subscriptions = subscriptions
  }

-- PORTS
port sendMsg : String -> Cmd msg

port receivedMsg : (String -> msg) -> Sub msg
port disconnected : (() -> msg) -> Sub msg

-- MODEL
type alias Model =
  { chatlog : List Chat
  , state : AppState
  }

type alias Chat =
  { from: Maybe String
  , content: String
  }

type AppState
  = Alert (String, AppState)
  | Prompt String
  | Chatting (String, String) -- Name, Topic
  | Disconnected

-- INIT
init : () -> (Model, Cmd Msg)
init _ =
  (Model [] (Prompt "What should we call you?"), Cmd.none)

-- UPDATE
type Msg
  = SubmitName String
  | SubmitTopic String
  | SendChat String
  | RecvChat Chat
  | ErrMsg String
  | UserAck
  | ErrCrit


update : Msg -> Model -> (Model, Cmd Msg)
update msg model = 
  case msg of
    SubmitName newname ->
      case model.state of 
        Chatting (oldname, _) ->
          -- if name is the same, then do nothing
          if oldname == newname then
            ( model, Cmd.none )
          else
            handleSubmitName model newname
        Prompt _ ->
            handleSubmitName model newname
        -- ignore commands if disconnected or processing an alert
        _ -> (model, Cmd.none)
    SubmitTopic newtopic ->
      case model.state of
        Chatting (name, oldtopic) ->
          -- if topic is the same, then do nothing
          if oldtopic == newtopic then
            ( model, Cmd.none )
          else if isBadName newtopic then
            ( { model | state = Alert ( badNameErr, model.state ) }
            , Cmd.none
            )
          else
            ( { model | state = Chatting ( name, newtopic ) }
            , submitTopic newtopic
            )
        -- ignore all other commands
        _ -> (model, Cmd.none)
    SendChat chat -> 
      ( model
      , sendChat chat
      )
    RecvChat chat ->
      ( { model | chatlog = chat :: model.chatlog }
      , Cmd.none
      )
    ErrMsg e ->
      ( { model | state = Alert (e, model.state) }
      , Cmd.none
      )
    UserAck ->
      case model.state of
        Alert (_, prevState) ->
          ( { model | state = prevState }
          , Cmd.none
          )
        -- Do nothing, because this message should not be generated
        _ -> ( model, Cmd.none )
    ErrCrit ->
      ( { model | state = Disconnected }
      ,  Cmd.none
      )

-- Possible commands to send to the websocket server
sendChat : String -> Cmd msg 
sendChat chat = 
  sendMsg <| String.concat ["{\"type\":\"message\",\"content\":\"", chat, "\"}"]

submitName : String -> Cmd msg 
submitName newname = 
  sendMsg <| String.concat ["{\"type\":\"name\",\"content\":\"", newname, "\"}"]

submitTopic : String -> Cmd msg
submitTopic newtopic =
  sendMsg <| String.concat ["{\"type\":\"room\",\"content\":\"", newtopic, "\"}"]

-- Error handling
handleSubmitName : Model -> String -> (Model, Cmd Msg)
handleSubmitName model newname =
  if isBadName newname then
    ( { model | state = Alert ( badNameErr, model.state ) }
    , Cmd.none
    )
  else
    ( { model | state = Chatting ( newname, getTopic model ) 
      }
    , submitName newname
    )

getTopic : Model -> String
getTopic model =
  case model.state of
    Chatting(_, topic) -> topic
    _ -> "Honda_Vehicles"

badNameErr : String
badNameErr =
  "Names can only contain letters, numbers, and underscores (\"_\")."

isBadName : String -> Bool
isBadName name =
  (String.length name) == 0 || Regex.contains illegalChars name

illegalChars : Regex.Regex
illegalChars = 
  Maybe.withDefault Regex.never 
    (Regex.fromString "[ \t\n\r-.?!@#$%^&*()<>:\"\'{}\'/\\\\]")

-- SUBSCRIPTIONS
subscriptions : Model -> Sub Msg
subscriptions model = 
  Sub.batch
  [ disconnected (always ErrCrit)
  , receivedMsg processMsg
  ]

processMsg : String -> Msg
processMsg data =
  case Decode.decodeString chatDecoder data of
    Err err -> ErrMsg (Decode.errorToString err)
    Ok chat -> RecvChat chat

chatDecoder : Decoder Chat
chatDecoder =
  Decode.map2 Chat
    (Decode.maybe (Decode.field "from" Decode.string))
    (Decode.field "content" Decode.string)

-- VIEW
view : Model -> Browser.Document Msg
view model =
  { title = title model
  , body = 
    [ div [id "main"] ( mainContent model) ]
  }

title : Model -> String
title model =
  case model.state of
    Chatting (_, topic) -> topic
    _ -> "Accord"

mainContent : Model -> List (Html.Html Msg)
mainContent model =
  case model.state of
    Chatting (name, topic) ->
      displayChat name topic model.chatlog
    Alert (e, _) ->
      displayAlert e
    Prompt msg ->
      displayPrompt msg
    Disconnected ->
      displayDisconnect


displayChat : String -> String -> List Chat -> List (Html.Html Msg)
displayChat name topic chatlog =
  [ div [ class "main-element", id "greeting" ] 
    [ text "Welcome, ", formField SubmitName name
    , Html.br [] []
    , text ("Today, we are chatting about: "), formField SubmitTopic topic
    ]
  , div [ class "main-element", id "chat-output"] 
      (chatlog |> List.reverse |> List.map viewSingleChat)
  , Html.textarea [ class "main-element", id "chat-input", 
      Attr.spellcheck True,
      Attr.placeholder "Enter a message here.",
      handleInput SendChat, Attr.value "" ] []
  ]


formField : (String -> Msg) -> String -> Html.Html Msg
formField field_type current_value = 
  Html.input [ Attr.spellcheck False, Attr.value current_value,
               class "form", handleInput field_type] []


viewSingleChat : Chat -> Html.Html msg
viewSingleChat {from, content} =
  case from of
    Nothing -> div [] [ text content ]
    Just f -> div [] [ text <| f ++ ": " ++ content]


displayAlert : String -> List (Html.Html Msg)
displayAlert error = 
  [ div [ class "main-element", class "error" ] [ text error ] 
  , Html.button [ class "main-element", Events.onClick UserAck ] [ text "Got it!"]
  ]


displayPrompt : String -> List (Html.Html Msg)
displayPrompt msg =
  [ div [ class "main-element" ] [ text msg ] 
  , Html.input
    [ class "main-element", id "input-bar", Attr.spellcheck False, 
      Attr.placeholder "enter username here", (handleInput SubmitName)] []
  ]


displayDisconnect : List (Html.Html Msg)
displayDisconnect = 
  [ div [ class "main-element", class "error"] 
    [ text "Oopsie! Looks like our servers are down!"]
  , div [ class "main-element", class "error"] 
      [ text "Try connecting later?" ]
  ]

{--| Receive a string from a textarea or input box.
Unlike the default onInput function, this only fires
when enter is pressed. 

All functions below this are for making handleInput work.
--}
handleInput : (String -> Msg) -> Html.Attribute Msg
handleInput msgtype =
  eventDecoder 
  |> Decode.andThen checkEnterShift
  |> Decode.map (\v -> (msgtype v, False) )
  |> Events.stopPropagationOn "keypress"

type alias Event =
  { shift : Bool
  , key : Int
  }

checkEnterShift: Event -> Decoder String
checkEnterShift e =
  if e.key == 13 then
    if e.shift then
      Decode.fail "Shift key pressed with enter"
    else
      Events.targetValue
  else
    Decode.fail "Shift key pressed with enter"


checkEnter: Event -> Decoder String
checkEnter e =
  if e.key == 13 then
    Events.targetValue
  else
    Decode.fail "Shift key pressed with enter"


eventDecoder : Decoder Event
eventDecoder = 
  Decode.map2 Event
    (Decode.field "shiftKey" Decode.bool)
    (Decode.field "keyCode" Decode.int)
