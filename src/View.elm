module View exposing (view)

import Data exposing (Data, Hour)
import Delight
import Html exposing (..)
import Html.Attributes exposing (class, style)
import Icons
import Rain
import Rules exposing (Call, Verdict(..), Window)


view : Data -> Html msg
view data =
    let
        workday =
            Rules.isWorkday data.weekday

        am =
            Rules.worst Rules.morningWindow data.hours

        pm =
            Rules.worst Rules.eveningWindow data.hours

        remark =
            Delight.remark data.yday (Delight.mood workday data.daily.code am pm)
    in
    div [ class "screen" ]
        [ header data
        , weatherRow data
        , if workday then
            verdicts data

          else
            dayOff
        , footer remark
        ]


header : Data -> Html msg
header data =
    div [ class "header" ]
        [ div [ class "weekday" ] [ text (String.toUpper data.weekday) ]
        , div [ class "stamp" ]
            [ div [] [ text (prettyDate data.date) ]
            , div [] [ text ("updated " ++ data.generatedAt) ]
            ]
        ]


weatherRow : Data -> Html msg
weatherRow data =
    div [ class "weather" ]
        [ div [ class "glyph" ] [ Icons.weather data.daily.code 110 ]
        , div [ class "temps" ]
            [ div [ class "range" ]
                [ text (String.fromInt (round data.daily.tmax) ++ "°")
                , span [ class "low" ] [ text (" / " ++ String.fromInt (round data.daily.tmin) ++ "°") ]
                ]
            , div [ class "summary" ] [ text (summary data.daily.code) ]
            , div [ class "sun" ] [ text ("sunrise " ++ data.daily.sunrise ++ "  ·  sunset " ++ data.daily.sunset) ]
            ]
        , hourStrip data
        ]


hourStrip : Data -> Html msg
hourStrip data =
    div [ class "strip" ]
        [ Rain.strip data.yday data.hours
        , div [ class "striplabel" ] [ text "rain chance by hour" ]
        ]


verdicts : Data -> Html msg
verdicts data =
    div [ class "verdicts" ]
        [ verdictCard "IN" (Rules.decide Rules.morningWindow data.hours) "06:44 · 07:06 · 07:15 from Cambridge South"
        , verdictCard "BACK" (Rules.decide Rules.eveningWindow data.hours) "from Cambridge North"
        ]


verdictCard : String -> Call -> String -> Html msg
verdictCard label call trains =
    let
        ( icon, word, extra ) =
            case call.verdict of
                Cycle ->
                    ( Icons.bike 72, "CYCLE", "" )

                CycleWet ->
                    ( Icons.bike 72, "CYCLE", "+ waterproofs" )

                Train ->
                    ( Icons.train 72, "TRAIN", trains )
    in
    div [ class ("card " ++ String.toLower word) ]
        [ div [ class "label" ] [ text label ]
        , div [ class "callrow" ]
            [ div [ class "icon" ] [ icon ]
            , div []
                [ div [ class "word" ] [ text word ]
                , div [ class "extra" ] [ text extra ]
                ]
            ]
        , div [ class "reason" ] [ text call.reason ]
        ]


dayOff : Html msg
dayOff =
    div [ class "dayoff" ]
        [ div [ class "word" ] [ text "NO COMMUTE" ]
        , div [ class "extra" ] [ text "Monday to Thursday are the only days that count." ]
        ]


footer : String -> Html msg
footer remark =
    div [ class "footer" ] [ text remark ]


summary : Int -> String
summary code =
    if code == 0 then
        "Clear"

    else if code == 1 then
        "Mostly clear"

    else if code == 2 then
        "Partly cloudy"

    else if code == 3 then
        "Overcast"

    else if code == 45 || code == 48 then
        "Fog"

    else if code >= 51 && code <= 57 then
        "Drizzle"

    else if code >= 61 && code <= 67 then
        "Rain"

    else if code >= 71 && code <= 77 then
        "Snow"

    else if code >= 80 && code <= 82 then
        "Showers"

    else if code == 85 || code == 86 then
        "Snow showers"

    else if code >= 95 then
        "Thunder"

    else
        "Changeable"


prettyDate : String -> String
prettyDate iso =
    case String.split "-" iso of
        [ _, m, d ] ->
            String.fromInt (Maybe.withDefault 0 (String.toInt d)) ++ " " ++ monthName m

        _ ->
            iso


monthName : String -> String
monthName m =
    case m of
        "01" -> "Jan"
        "02" -> "Feb"
        "03" -> "Mar"
        "04" -> "Apr"
        "05" -> "May"
        "06" -> "Jun"
        "07" -> "Jul"
        "08" -> "Aug"
        "09" -> "Sep"
        "10" -> "Oct"
        "11" -> "Nov"
        "12" -> "Dec"
        _ -> m
