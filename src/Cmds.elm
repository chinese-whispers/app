module Cmds exposing (cmdsForRoute)

import Api
import Model exposing (Model)
import Msg exposing (Msg)
import Profile.Msg as ProfileMsg
import Router
import Store
import Task
import Types


cmdsForRoute : Model -> Router.Route -> List (Cmd Msg)
cmdsForRoute model route =
    case route of
        {-
           TODO: for exp route:
           - get necessary sentences (train/exp) upon opening the route, and show "loading" until loaded. If nothing, or not enough to finish current sequence, show error
           - Start instructions if not introduced
        -}
        Router.Profile profileRoute ->
            authenticatedOrIgnore model <|
                \auth ->
                    case profileRoute of
                        Router.Confirm key ->
                            case model.emailConfirmation of
                                Model.SendingConfirmation ->
                                    [ Task.perform
                                        (Msg.ProfileMsg << ProfileMsg.EmailConfirmationFail)
                                        (Msg.ProfileMsg << ProfileMsg.EmailConfirmationSuccess)
                                        (Api.confirmEmail key auth)
                                    ]

                                _ ->
                                    []

                        Router.Dashboard ->
                            case auth.user.profile.wordSpanId of
                                Nothing ->
                                    []

                                Just id ->
                                    [ Task.perform
                                        Msg.Error
                                        (Msg.GotStoreItem << Store.WordSpan)
                                        (Api.fetch model.store.wordSpans id auth)
                                    ]

                        Router.Questionnaire ->
                            [ fetchMeta model ]

                        _ ->
                            []

        Router.Experiment ->
            authenticatedOrIgnore model <|
                \auth ->
                    [ fetchMeta model ]

        _ ->
            []



-- CMD HELPERS


authenticatedOrIgnore :
    Model
    -> (Types.Auth -> List (Cmd Msg))
    -> List (Cmd Msg)
authenticatedOrIgnore model authFunc =
    case model.auth of
        Types.Authenticated auth ->
            authFunc auth

        _ ->
            []


fetchMeta : Model -> Cmd Msg
fetchMeta model =
    case model.store.meta of
        Nothing ->
            Task.perform Msg.Error Msg.GotMeta Api.fetchMeta

        Just _ ->
            Cmd.none
