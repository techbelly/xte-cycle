module Main exposing (main)

import Browser
import Data
import Html exposing (Html, div, pre, text)
import Html.Attributes exposing (class)
import Json.Decode as D
import View


type alias Model =
    Result D.Error Data.Data


main : Program D.Value Model ()
main =
    Browser.element
        { init = \flags -> ( D.decodeValue Data.decoder flags, Cmd.none )
        , view = view
        , update = \_ model -> ( model, Cmd.none )
        , subscriptions = \_ -> Sub.none
        }


view : Model -> Html ()
view model =
    case model of
        Ok data ->
            View.view data

        Err err ->
            div [ class "screen error" ]
                [ div [ class "weekday" ] [ text "NO DATA" ]
                , pre [] [ text (D.errorToString err) ]
                ]
