module Data exposing (Daily, Data, Hour, decoder)

{-| The facts the Ruby fetcher wrote. No opinions live here.
-}

import Json.Decode as D exposing (Decoder)


type alias Data =
    { date : String
    , weekday : String
    , yday : Int
    , generatedAt : String
    , location : String
    , daily : Daily
    , hours : List Hour
    }


type alias Daily =
    { sunrise : String
    , sunset : String
    , tmax : Float
    , tmin : Float
    , code : Int
    }


type alias Hour =
    { hour : Int
    , temp : Float
    , rainProb : Int
    , precip : Float
    , wind : Float
    , gust : Float
    , code : Int
    }


decoder : Decoder Data
decoder =
    D.map7 Data
        (D.field "date" D.string)
        (D.field "weekday" D.string)
        (D.field "yday" D.int)
        (D.field "generated_at" D.string)
        (D.field "location" D.string)
        (D.field "daily" dailyDecoder)
        (D.field "hours" (D.list hourDecoder))


dailyDecoder : Decoder Daily
dailyDecoder =
    D.map5 Daily
        (D.field "sunrise" D.string)
        (D.field "sunset" D.string)
        (D.field "tmax" D.float)
        (D.field "tmin" D.float)
        (D.field "code" D.int)


hourDecoder : Decoder Hour
hourDecoder =
    D.map7 Hour
        (D.field "hour" D.int)
        (D.field "temp" D.float)
        (D.field "rain_prob" D.int)
        (D.field "precip" D.float)
        (D.field "wind" D.float)
        (D.field "gust" D.float)
        (D.field "code" D.int)
