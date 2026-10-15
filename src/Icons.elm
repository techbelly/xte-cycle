module Icons exposing (bike, train, weather)

{-| Hand-drawn black-and-white glyphs, stroke based so they threshold cleanly.
-}

import Html exposing (Html)
import Svg exposing (..)
import Svg.Attributes exposing (..)


stroked : Int -> List (Svg msg) -> Html msg
stroked size children =
    svg
        [ width (String.fromInt size)
        , height (String.fromInt size)
        , viewBox "0 0 100 100"
        , fill "none"
        , stroke "black"
        , strokeWidth "6"
        , strokeLinecap "round"
        , strokeLinejoin "round"
        ]
        children


bike : Int -> Html msg
bike size =
    stroked size
        [ circle [ cx "24", cy "68", r "18" ] []
        , circle [ cx "76", cy "68", r "18" ] []
        , polyline [ points "24,68 42,36 66,36 76,68" ] []
        , polyline [ points "42,36 52,68 24,68" ] []
        , line [ x1 "52", y1 "68", x2 "66", y2 "36" ] []
        , line [ x1 "60", y1 "22", x2 "70", y2 "22" ] []
        , line [ x1 "66", y1 "36", x2 "64", y2 "22" ] []
        , line [ x1 "36", y1 "36", x2 "48", y2 "36" ] []
        ]


train : Int -> Html msg
train size =
    stroked size
        [ rect [ x "18", y "14", width "64", height "58", rx "12" ] []
        , rect [ x "28", y "26", width "18", height "18", rx "3" ] []
        , rect [ x "54", y "26", width "18", height "18", rx "3" ] []
        , line [ x1 "18", y1 "56", x2 "82", y2 "56" ] []
        , circle [ cx "34", cy "64", r "3", fill "black" ] []
        , circle [ cx "66", cy "64", r "3", fill "black" ] []
        , line [ x1 "30", y1 "72", x2 "20", y2 "88" ] []
        , line [ x1 "70", y1 "72", x2 "80", y2 "88" ] []
        , line [ x1 "40", y1 "6", x2 "60", y2 "6" ] []
        ]


{-| Pick a glyph from a WMO weather code.
-}
weather : Int -> Int -> Html msg
weather code size =
    if code == 0 then
        sun size

    else if code <= 2 then
        sunCloud size

    else if code == 3 || code == 45 || code == 48 then
        cloud size

    else if code >= 95 then
        thunder size

    else if List.member code [ 71, 73, 75, 77, 85, 86 ] then
        snow size

    else
        rain size


sun : Int -> Html msg
sun size =
    stroked size (circle [ cx "50", cy "50", r "20" ] [] :: rays 50 50 30 42)


rays : Float -> Float -> Float -> Float -> List (Svg msg)
rays cxF cyF r1 r2 =
    List.range 0 7
        |> List.map
            (\i ->
                let
                    a =
                        toFloat i * pi / 4
                in
                line
                    [ x1 (String.fromFloat (cxF + r1 * cos a))
                    , y1 (String.fromFloat (cyF + r1 * sin a))
                    , x2 (String.fromFloat (cxF + r2 * cos a))
                    , y2 (String.fromFloat (cyF + r2 * sin a))
                    ]
                    []
            )


cloudPath : String
cloudPath =
    "M30,78 h44 a16,16 0 0 0 2,-32 a22,22 0 0 0 -42,-6 a16,16 0 0 0 -4,38 z"


cloud : Int -> Html msg
cloud size =
    stroked size [ Svg.path [ d cloudPath ] [] ]


sunCloud : Int -> Html msg
sunCloud size =
    stroked size
        (circle [ cx "66", cy "34", r "14" ] []
            :: Svg.path [ d "M22,84 h40 a14,14 0 0 0 2,-28 a19,19 0 0 0 -36,-5 a14,14 0 0 0 -6,33 z", fill "white" ] []
            :: rays 66 34 22 30
        )


rain : Int -> Html msg
rain size =
    stroked size
        [ Svg.path [ d "M30,64 h44 a16,16 0 0 0 2,-32 a22,22 0 0 0 -42,-6 a16,16 0 0 0 -4,38 z" ] []
        , line [ x1 "38", y1 "76", x2 "32", y2 "92" ] []
        , line [ x1 "54", y1 "76", x2 "48", y2 "92" ] []
        , line [ x1 "70", y1 "76", x2 "64", y2 "92" ] []
        ]


snow : Int -> Html msg
snow size =
    stroked size
        [ Svg.path [ d "M30,64 h44 a16,16 0 0 0 2,-32 a22,22 0 0 0 -42,-6 a16,16 0 0 0 -4,38 z" ] []
        , circle [ cx "36", cy "84", r "3", fill "black" ] []
        , circle [ cx "52", cy "84", r "3", fill "black" ] []
        , circle [ cx "68", cy "84", r "3", fill "black" ] []
        ]


thunder : Int -> Html msg
thunder size =
    stroked size
        [ Svg.path [ d "M30,60 h44 a16,16 0 0 0 2,-32 a22,22 0 0 0 -42,-6 a16,16 0 0 0 -4,38 z" ] []
        , polyline [ points "54,62 44,80 56,80 46,98", fill "none" ] []
        ]
