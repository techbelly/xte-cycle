module Rain exposing (strip)

{-| Rain chance by hour as a scatter of tiny drops: more drops where rain is
likelier, slanted by the gusts. Positions come from a seeded generator so the
picture is the same all day and different tomorrow.
-}

import Data exposing (Hour)
import Html exposing (Html)
import Svg exposing (..)
import Svg.Attributes exposing (..)


width_ : Int
width_ =
    350


plotHeight : Int
plotHeight =
    66


labelHeight : Int
labelHeight =
    20


firstHour : Int
firstHour =
    5


lastHour : Int
lastHour =
    18


maxDropsPerHour : Int
maxDropsPerHour =
    22


strip : Int -> List Hour -> Html msg
strip seed hours =
    let
        shown =
            List.filter (\h -> h.hour >= firstHour && h.hour <= lastHour) hours

        colW =
            toFloat width_ / toFloat (lastHour - firstHour + 1)

        ( drops, _ ) =
            List.foldl (column colW) ( [], seed * 7919 + 17 ) shown
    in
    svg
        [ Svg.Attributes.width (String.fromInt width_)
        , Svg.Attributes.height (String.fromInt (plotHeight + labelHeight))
        , viewBox ("0 0 " ++ String.fromInt width_ ++ " " ++ String.fromInt (plotHeight + labelHeight))
        ]
        (line
            [ x1 "0"
            , y1 (String.fromInt plotHeight)
            , x2 (String.fromInt width_)
            , y2 (String.fromInt plotHeight)
            , stroke "black"
            , strokeWidth "2"
            ]
            []
            :: List.map (label colW) shown
            ++ drops
        )


label : Float -> Hour -> Svg msg
label colW h =
    let
        cx_ =
            (toFloat (h.hour - firstHour) + 0.5) * colW
    in
    text_
        [ x (String.fromFloat cx_)
        , y (String.fromInt (plotHeight + labelHeight - 4))
        , textAnchor "middle"
        , fontSize "15"
        , fontFamily "Atkinson, Helvetica, Arial, sans-serif"
        ]
        [ text (String.fromInt h.hour) ]


column : Float -> Hour -> ( List (Svg msg), Int ) -> ( List (Svg msg), Int )
column colW h ( acc, seed ) =
    let
        n =
            round (toFloat h.rainProb / 100 * toFloat maxDropsPerHour)

        x0 =
            toFloat (h.hour - firstHour) * colW

        -- Lean with the wind: 0 degrees in calm, about 35 degrees in a gale.
        slant =
            Basics.min 35 (h.gust / 60 * 35)

        go k s out =
            if k <= 0 then
                ( out, s )

            else
                let
                    ( ux, s1 ) =
                        next s

                    ( uy, s2 ) =
                        next s1

                    dx =
                        x0 + 3 + ux * (colW - 6)

                    dy =
                        4 + uy * toFloat (plotHeight - 10)
                in
                go (k - 1) s2 (drop dx dy slant :: out)
    in
    go n seed acc


drop : Float -> Float -> Float -> Svg msg
drop dx dy slant =
    let
        f =
            String.fromFloat

        -- an 8px teardrop: point at the top, round at the bottom
        d_ =
            "M " ++ f dx ++ " " ++ f (dy - 4.4)
                ++ " L " ++ f (dx - 2.4) ++ " " ++ f (dy + 0.8)
                ++ " A 2.4 2.4 0 0 0 " ++ f (dx + 2.4) ++ " " ++ f (dy + 0.8)
                ++ " Z"
    in
    Svg.path
        [ d d_
        , fill "black"
        , transform ("rotate(" ++ f slant ++ " " ++ f dx ++ " " ++ f dy ++ ")")
        ]
        []


{-| MINSTD generator: returns a unit float and the next seed.
-}
next : Int -> ( Float, Int )
next seed =
    let
        s =
            modBy 2147483647 (seed * 48271)

        s1 =
            if s == 0 then
                1

            else
                s
    in
    ( toFloat s1 / 2147483647, s1 )
