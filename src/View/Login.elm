module View.Login exposing (view)

import Feedback
import Form
import Helpers
import Html
import Html.Attributes as Attributes
import Html.Events as Events
import Model exposing (Model)
import Msg exposing (Msg)
import Router
import Types


view : Model -> Html.Html Msg
view model =
    Html.div [] [ header, body model ]


header : Html.Html Msg
header =
    Html.div []
        [ Helpers.navButton Router.Home "Back"
        , Html.h1 [] [ Html.text "Sign in" ]
        ]


body : Model -> Html.Html Msg
body model =
    let
        inner =
            case model.auth of
                Types.Anonymous ->
                    form model.login

                Types.Authenticating ->
                    Helpers.loading

                Types.Authenticated { user } ->
                    Helpers.alreadyAuthed user
    in
        Html.div [] [ inner ]


form : Form.Model Types.Credentials -> Html.Html Msg
form { input, feedback, status } =
    Html.div []
        [ Html.div []
            [ Html.text "No account yet? "
            , Helpers.navA (Router.Register Nothing) "Sign up"
            , Html.text "!"
            ]
        , Html.form [ Events.onSubmit (Msg.Login input) ]
            [ Html.div []
                [ Html.label [ Attributes.for "inputUsername" ] [ Html.text "Username" ]
                , Html.input
                    [ Attributes.id "inputUsername"
                    , Attributes.disabled (status == Form.Sending)
                    , Attributes.autofocus True
                    , Attributes.placeholder "joey"
                    , Attributes.type' "text"
                    , Attributes.value input.username
                    , Events.onInput (Msg.LoginFormInput << \u -> { input | username = u })
                    ]
                    []
                , Html.span [] [ Html.text (Feedback.getError "username" feedback) ]
                ]
            , Html.div []
                [ Html.label [ Attributes.for "inputPassword" ] [ Html.text "Password" ]
                , Html.input
                    [ Attributes.id "inputPassword"
                    , Attributes.disabled (status == Form.Sending)
                    , Attributes.placeholder "ubA1oh"
                    , Attributes.type' "password"
                    , Attributes.value input.password
                    , Events.onInput (Msg.LoginFormInput << \p -> { input | password = p })
                    ]
                    []
                , Html.span [] [ Html.text (Feedback.getError "password" feedback) ]
                ]
            , Html.div []
                [ Html.span [] [ Html.text (Feedback.getError "global" feedback) ]
                , Html.button
                    [ Attributes.type' "submit"
                    , Attributes.disabled (status == Form.Sending)
                    ]
                    [ Html.text "Sign in" ]
                , Helpers.navA Router.Recover "I forgot my password"
                ]
            ]
        ]
