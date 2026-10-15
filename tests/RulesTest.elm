module RulesTest exposing (suite)

import Data exposing (Hour)
import Expect
import Rules exposing (Verdict(..))
import Test exposing (..)


hour : Int -> Hour
hour h =
    { hour = h, temp = 12, rainProb = 5, precip = 0, wind = 10, gust = 20, code = 1 }


day : List Hour
day =
    List.map hour (List.range 0 23)


with : Int -> (Hour -> Hour) -> List Hour -> List Hour
with h f =
    List.map
        (\x ->
            if x.hour == h then
                f x

            else
                x
        )


verdictAt : Rules.Window -> List Hour -> Verdict
verdictAt w hs =
    (Rules.decide w hs).verdict


suite : Test
suite =
    describe "Rules"
        [ test "a dry mild day is a cycle both ways" <|
            \_ ->
                ( verdictAt Rules.morningWindow day, verdictAt Rules.eveningWindow day )
                    |> Expect.equal ( Cycle, Cycle )
        , test "likely rain in the morning window means train in, cycle back" <|
            \_ ->
                let
                    hs =
                        day |> with 6 (\x -> { x | rainProb = 70 })
                in
                ( verdictAt Rules.morningWindow hs, verdictAt Rules.eveningWindow hs )
                    |> Expect.equal ( Train, Cycle )
        , test "rain outside the windows is ignored" <|
            \_ ->
                day
                    |> with 12 (\x -> { x | rainProb = 100, precip = 5 })
                    |> verdictAt Rules.morningWindow
                    |> Expect.equal Cycle
        , test "a fair chance of showers is cycle with waterproofs" <|
            \_ ->
                day
                    |> with 17 (\x -> { x | rainProb = 40 })
                    |> verdictAt Rules.eveningWindow
                    |> Expect.equal CycleWet
        , test "strong gusts mean train" <|
            \_ ->
                day
                    |> with 7 (\x -> { x | gust = 60 })
                    |> verdictAt Rules.morningWindow
                    |> Expect.equal Train
        , test "freezing means train" <|
            \_ ->
                day
                    |> with 5 (\x -> { x | temp = -1 })
                    |> verdictAt Rules.morningWindow
                    |> Expect.equal Train
        , test "thunder code overrides fine numbers" <|
            \_ ->
                day
                    |> with 16 (\x -> { x | code = 95 })
                    |> Rules.decide Rules.eveningWindow
                    |> Expect.equal { verdict = Train, reason = "thunder forecast" }
        , test "heavy rain quotes the rate" <|
            \_ ->
                day
                    |> with 6 (\x -> { x | precip = 1.4 })
                    |> Rules.decide Rules.morningWindow
                    |> Expect.equal { verdict = Train, reason = "rain, 1.4 mm/h" }
        , test "only Monday to Thursday are workdays" <|
            \_ ->
                List.map Rules.isWorkday [ "Monday", "Thursday", "Friday", "Saturday", "Sunday" ]
                    |> Expect.equal [ True, True, False, False, False ]
        ]
