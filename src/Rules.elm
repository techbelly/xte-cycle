module Rules exposing
    ( Call
    , Verdict(..)
    , Window
    , Worst
    , decide
    , eveningWindow
    , isWorkday
    , morningWindow
    , worst
    )

{-| The cycle-or-train decision. Dead simple on purpose: look at the worst
hour in each commute window and apply fixed thresholds.
-}

import Data exposing (Hour)


type alias Window =
    { from : Int, to : Int }


{-| Set off between 06:00 and 07:00, sometimes a little earlier.
Hours are inclusive, so this covers the 05:00, 06:00 and 07:00 forecasts.
-}
morningWindow : Window
morningWindow =
    { from = 5, to = 7 }


{-| Head home between 16:00 and 17:00.
-}
eveningWindow : Window
eveningWindow =
    { from = 16, to = 17 }


isWorkday : String -> Bool
isWorkday weekday =
    List.member weekday [ "Monday", "Tuesday", "Wednesday", "Thursday" ]


type Verdict
    = Cycle
    | CycleWet
    | Train


type alias Call =
    { verdict : Verdict
    , reason : String
    }


type alias Worst =
    { rainProb : Int
    , precip : Float
    , gust : Float
    , temp : Float
    , codes : List Int
    }


inWindow : Window -> Hour -> Bool
inWindow w h =
    h.hour >= w.from && h.hour <= w.to


worst : Window -> List Hour -> Maybe Worst
worst w hours =
    case List.filter (inWindow w) hours of
        [] ->
            Nothing

        hs ->
            Just
                { rainProb = List.maximum (List.map .rainProb hs) |> Maybe.withDefault 0
                , precip = List.maximum (List.map .precip hs) |> Maybe.withDefault 0
                , gust = List.maximum (List.map .gust hs) |> Maybe.withDefault 0
                , temp = List.minimum (List.map .temp hs) |> Maybe.withDefault 0
                , codes = List.map .code hs
                }


{-| WMO weather codes that are a no regardless of the numbers:
thunderstorms (95-99), freezing rain and drizzle (56, 57, 66, 67),
snow (71-77, 85, 86).
-}
nastyCodes : List Int
nastyCodes =
    [ 56, 57, 66, 67, 71, 73, 75, 77, 85, 86, 95, 96, 99 ]


decide : Window -> List Hour -> Call
decide w hours =
    case worst w hours of
        Nothing ->
            { verdict = Train, reason = "no forecast for this window" }

        Just x ->
            if List.any (\c -> List.member c nastyCodes) x.codes then
                { verdict = Train, reason = codeReason x.codes }

            else if x.temp <= 0 then
                { verdict = Train, reason = "ice risk, " ++ showTemp x.temp }

            else if x.gust >= 55 then
                { verdict = Train, reason = "gusts to " ++ showKmh x.gust }

            else if x.precip >= 1.0 then
                { verdict = Train, reason = "rain, " ++ showMm x.precip }

            else if x.rainProb >= 60 then
                { verdict = Train, reason = "rain, " ++ String.fromInt x.rainProb ++ "% likely" }

            else if x.rainProb >= 35 || x.precip >= 0.2 then
                { verdict = CycleWet, reason = "showers possible, " ++ String.fromInt x.rainProb ++ "%" }

            else if x.gust >= 40 then
                { verdict = Cycle, reason = "dry but breezy, gusts " ++ showKmh x.gust }

            else
                { verdict = Cycle, reason = "dry, " ++ showTemp x.temp }


codeReason : List Int -> String
codeReason codes =
    if List.any (\c -> c >= 95) codes then
        "thunder forecast"

    else if List.any (\c -> List.member c [ 56, 57, 66, 67 ]) codes then
        "freezing rain"

    else
        "snow forecast"


showTemp : Float -> String
showTemp t =
    String.fromInt (round t) ++ "°"


showMm : Float -> String
showMm v =
    String.fromFloat (toFloat (round (v * 10)) / 10) ++ " mm/h"


showKmh : Float -> String
showKmh v =
    String.fromInt (round v) ++ " km/h"
