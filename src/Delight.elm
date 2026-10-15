module Delight exposing (Mood(..), mood, remark)

{-| The fun bit. One dry line a day, chosen by the day of the year so it is
stable all day and different tomorrow.
-}

import Rules exposing (Verdict(..), Worst)


type Mood
    = Sunny
    | Grey
    | Showery
    | Wet
    | Windy
    | Cold
    | Nasty
    | DayOff


mood : Bool -> Int -> Maybe Worst -> Maybe Worst -> Mood
mood workday dailyCode am pm =
    let
        both f =
            Basics.max (Maybe.map f am |> Maybe.withDefault 0) (Maybe.map f pm |> Maybe.withDefault 0)

        coldest =
            Basics.min (Maybe.map .temp am |> Maybe.withDefault 99) (Maybe.map .temp pm |> Maybe.withDefault 99)
    in
    if not workday then
        DayOff

    else if dailyCode >= 71 && dailyCode /= 80 && dailyCode /= 81 && dailyCode /= 82 then
        Nasty

    else if coldest <= 1 then
        Cold

    else if both .gust >= 50 then
        Windy

    else if both (toFloat << .rainProb) >= 60 then
        Wet

    else if both (toFloat << .rainProb) >= 35 then
        Showery

    else if dailyCode <= 1 then
        Sunny

    else
        Grey


remark : Int -> Mood -> String
remark yday m =
    let
        lines =
            linesFor m
    in
    List.drop (modBy (List.length lines) yday) lines
        |> List.head
        |> Maybe.withDefault ""


linesFor : Mood -> List String
linesFor m =
    case m of
        Sunny ->
            [ "Fen sun. Rarer than a free punt."
            , "Dry roads, dry wit."
            , "A fine day to overtake a delivery rider on the guided busway."
            , "Shades on. The Science Park awaits."
            , "Big sky, no excuses."
            ]

        Grey ->
            [ "Fifty shades of Cambridge."
            , "Standard issue East Anglian lid."
            , "The sun is up there somewhere. Probably."
            , "Sky the colour of the Backs in February."
            , "Grey, but it's a dry grey."
            ]

        Showery ->
            [ "Pack the jacket. Don't pack the optimism."
            , "Mudguards earn their keep today."
            , "Showers possible. So is anything."
            , "A bit damp, like a college bop."
            , "Fifty-fifty. The forecast shrugs."
            ]

        Wet ->
            [ "The fens were wetlands once. They remember."
            , "Even the ducks have cancelled."
            , "Proper rain. Book a window seat."
            , "Let the train take the strain and the rain."
            , "Cam's full enough without you in it."
            ]

        Windy ->
            [ "Headwind out, headwind back. It's a Cambridge thing."
            , "Flat county, big sky, large wind."
            , "Hold on to your gown."
            , "Tailwind one way. Guess which."
            , "The Fens are blowing through today."
            ]

        Cold ->
            [ "Scrape the saddle."
            , "Brass monkeys on Milton Road."
            , "Crisp. Possibly literally."
            , "Layers. All of them."
            , "Mind the black ice by the river."
            ]

        Nasty ->
            [ "Nope."
            , "Nature says no."
            , "Today the railway is your friend."
            , "Live to ride another day."
            , "Not a cycling day. Not even close."
            ]

        DayOff ->
            [ "No commute. The bike can have a lie-in too."
            , "The forecast is irrelevant and that's lovely."
            , "Weather is for looking at today."
            , "Rest day. The Science Park will cope."
            , "Nowhere to be. Nothing to decide."
            ]
