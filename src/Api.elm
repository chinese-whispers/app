module Api exposing (call, authCall, login, loginUser, logout)

import Decoders
import Encoders
import HttpBuilder exposing (RequestBuilder)
import Msg exposing (Msg(..))
import Task
import Types


baseUrl : String
baseUrl =
    "//127.0.0.1:8000/api"


call : (String -> RequestBuilder) -> String -> RequestBuilder
call method url =
    method (baseUrl ++ url)
        |> HttpBuilder.withHeader "Content-Type" "application/json"
        |> HttpBuilder.withHeader "Accept" "application/json"


authCall : (String -> RequestBuilder) -> String -> Types.Token -> RequestBuilder
authCall method url token =
    call method url
        |> HttpBuilder.withHeader "Authorization" ("Token " ++ token)


badOr : (String -> a) -> HttpBuilder.Error a -> a
badOr default error =
    case error of
        HttpBuilder.BadResponse response ->
            response.data

        _ ->
            default (toString error)


login : Types.Credentials -> Cmd Msg
login credentials =
    let
        task =
            call HttpBuilder.post "/rest-auth/login/"
                |> HttpBuilder.withJsonBody (Encoders.credentials credentials)
                |> HttpBuilder.send
                    (HttpBuilder.jsonReader Decoders.token)
                    (HttpBuilder.jsonReader (Decoders.feedback loginFeedbackFields))
    in
        Task.perform
            (badOr Types.globalFeedback >> LoginTokenFail)
            (.data >> LoginTokenSuccess)
            task


loginFeedbackFields : List String
loginFeedbackFields =
    [ "username", "password", "global" ]


loginUser : Types.Token -> Cmd Msg
loginUser token =
    let
        task =
            authCall HttpBuilder.get "/users/me/" token
                |> HttpBuilder.send
                    (HttpBuilder.jsonReader Decoders.user)
                    (HttpBuilder.jsonReader Decoders.detail)
    in
        Task.perform
            (badOr identity >> LoginUserFail)
            (.data >> LoginUserSuccess token)
            task


logout : Types.Token -> Cmd Msg
logout token =
    let
        task =
            authCall HttpBuilder.post "/rest-auth/logout/" token
                |> HttpBuilder.send
                    (always (Ok ()))
                    (HttpBuilder.jsonReader Decoders.detail)
    in
        Task.perform
            (badOr identity >> LogoutFail)
            (always LogoutSuccess)
            task
