port module Main exposing (main)

import Browser
import Html exposing (div, text)
import Html.Attributes as Attr exposing (id, class)
import Html.Events as Events
import Json.Decode as Decode exposing (Decoder)
import Json.Encode exposing (encode, object, string)
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

type alias Profile =
  { name: String
  , topic: String
  , inProgress: String
  }

type AppState
  = Alert (String, AppState)
  | Prompt String
  | Chatting Profile -- Name, Topic
  | Disconnected

-- INIT
init : () -> (Model, Cmd Msg)
init _ =
  (Model [] (Prompt "What should we call you?"), Cmd.none)

-- UPDATE
type Msg
  = SubmitName String
  | SubmitTopic String
  | SendChat
  | ComposeChat String
  | RecvChat Chat
  | ErrMsg String
  | UserAck
  | ErrCrit


update : Msg -> Model -> (Model, Cmd Msg)
update msg model = 
  case msg of
    SubmitName newname ->
      handleSubmitName model newname
    SubmitTopic newtopic ->
      case model.state of
        Chatting {name, topic, inProgress} ->
          -- if topic is the same, then do nothing
          if topic == newtopic then
            ( model, Cmd.none )
          else if isBadName newtopic then
            ( { model | state = Alert ( badNameErr, model.state ) }
            , Cmd.none
            )
          else
            ( { model | state = Chatting <| Profile name newtopic inProgress }
            , submitTopic newtopic
            )
        -- ignore all other commands
        _ -> (model, Cmd.none)
    SendChat -> 
      case model.state of 
        Chatting {name, topic, inProgress} ->
            ( {model | state = Chatting <| Profile name topic ""}
            , sendChat inProgress
            )
        -- ignore chats if not in chatting mode
        _ -> (model, Cmd.none)
    ComposeChat updated ->
      case model.state of
        Chatting {name, topic, inProgress} ->
            ( {model | state = Chatting <| Profile name topic updated}
            , Cmd.none
            )
        _ -> (model, Cmd.none)
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
  sendMsg <| encode 0 <| object [ ("kind", string "message"), ("content", string chat) ]

submitName : String -> Cmd msg 
submitName newname = 
  sendMsg <| encode 0 <| object [ ("kind", string "name"), ("content", string newname) ]

submitTopic : String -> Cmd msg
submitTopic newtopic =
  sendMsg <| encode 0 <| object [ ("kind", string "room"), ("content", string newtopic) ]

-- Error handling
handleSubmitName : Model -> String -> (Model, Cmd Msg)
handleSubmitName model newname =
  if isBadName newname then
    ( { model | state = Alert ( badNameErr, model.state ) }
    , Cmd.none
    )
  else
    case model.state of
      Chatting profile ->
        if newname == profile.name then
          ( model, Cmd.none)
        else
          let updated = { profile | name = newname } in
          ( { model | state = Chatting updated }
          , submitName newname
          )
      Prompt _ -> 
        ( { model | state = Chatting <| Profile newname "Honda-Vehicles" "" }
        , submitName newname
        )
      -- this command is invalid, if user isn't chatting or prompted
      _ -> ( model, Cmd.none )

badNameErr : String
badNameErr =
  "Names can only contain letters, numbers, and dashes (\"-\")."

isBadName : String -> Bool
isBadName name =
  (String.length name) == 0 || Regex.contains illegalChars name

illegalChars : Regex.Regex
illegalChars = 
  Maybe.withDefault Regex.never 
    (Regex.fromString "[ \t\n\r_.?!@#$%^&*()<>:\"\'{}\'/\\\\]")

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
    Chatting profile -> profile.topic
    _ -> "Accord"

mainContent : Model -> List (Html.Html Msg)
mainContent model =
  case model.state of
    Chatting profile ->
      displayChat profile model.chatlog
    Alert (e, _) ->
      displayAlert e
    Prompt msg ->
      displayPrompt msg
    Disconnected ->
      displayDisconnect


displayChat : Profile -> List Chat -> List (Html.Html Msg)
displayChat {name, topic, inProgress} chatlog =
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
      onEnter (always SendChat), Events.onInput ComposeChat, Attr.value inProgress ] []
  ]


formField : (String -> Msg) -> String -> Html.Html Msg
formField field_type current_value = 
  Html.input [ Attr.spellcheck False, Attr.value current_value,
               class "form", onEnter field_type] []


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
      Attr.placeholder "enter username here", (onEnter SubmitName)] []
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

All functions below this are for making onEnter work.
--}
onEnter : (String -> Msg) -> Html.Attribute Msg
onEnter msgtype =
  eventDecoder 
  |> Decode.andThen checkEnterShift
  |> Decode.map (\v -> (msgtype v, True) )
  |> Events.preventDefaultOn "keypress"


type alias Event =
  { shift : Bool
  , key : Int
  }


checkEnterShift: Event -> Decoder String
checkEnterShift e =
  if e.key == 13 && not e.shift then
      Events.targetValue
  else
      Decode.fail "enter not pressed"


eventDecoder : Decoder Event
eventDecoder = 
  Decode.map2 Event
    (Decode.field "shiftKey" Decode.bool)
    (Decode.field "keyCode" Decode.int)
