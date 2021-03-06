module Experiment.View exposing (view, instructions)

import Autoresize
import Clock
import Comment.Msg as CommentMsg
import Experiment.Model as ExpModel
import Experiment.Msg exposing (Msg(..))
import Feedback
import Form
import Helpers
import Html
import Html.Attributes as Attributes
import Html.Events as Events
import Intro
import Lifecycle
import List.Nonempty as Nonempty
import List.Nonempty exposing (Nonempty)
import Model exposing (Model)
import Msg as AppMsg
import Router
import Strings
import Styles exposing (class, classList, id)
import Types
import View.Common as Common


-- VIEW


view : (Msg -> AppMsg.Msg) -> Model -> List (Html.Html AppMsg.Msg)
view lift model =
    case model.auth of
        Types.Authenticated { user, meta } ->
            let
                ( body, progressView ) =
                    contents lift user.profile meta model
            in
                [ Html.header [] <|
                    (header lift user.profile meta model.experiment)
                        ++ progressView
                , Html.main_ [] [ body ]
                ]

        Types.Authenticating ->
            [ Helpers.loading Styles.Big ]

        Types.Anonymous ->
            [ Helpers.notAuthed ]



-- HEADER


header :
    (Msg -> AppMsg.Msg)
    -> Types.Profile
    -> Types.Meta
    -> ExpModel.Model
    -> List (Html.Html AppMsg.Msg)
header lift profile meta model =
    let
        title =
            case Lifecycle.state meta profile of
                Lifecycle.Training _ ->
                    "Experiment — Training"

                Lifecycle.Experiment _ ->
                    "Experiment"

                Lifecycle.Done ->
                    "Experiment — Done"
    in
        [ Html.nav [] [ Helpers.navIcon [ class [ Styles.Big ] ] Router.Home "home" ]
        , Intro.node
            (instructionsConfig lift profile meta)
            (ExpModel.instructionsState model)
            ExpModel.Title
            Html.h1
            []
            [ Html.text title ]
        ]



-- INSTRUCTIONS


jabberwockyVersion : Types.Meta -> ( a, a ) -> a
jabberwockyVersion meta ( normal, jabberwocky ) =
    if meta.jabberwockyMode then
        jabberwocky
    else
        normal


instructionsConfig :
    (Msg -> AppMsg.Msg)
    -> Types.Profile
    -> Types.Meta
    -> Intro.ViewConfig ExpModel.Node AppMsg.Msg
instructionsConfig lift profile meta =
    let
        quit =
            if profile.introducedExpPlay then
                Just "Skip"
            else
                Nothing
    in
        Intro.customViewConfig
            { maybeLabelQuit = quit
            , labelDone = "Done"
            , labelBack = "← Back"
            , labelNext = "Next →"
            , liftMsg = lift << InstructionsMsg
            , tooltip = (\i -> Tuple.second <| Nonempty.get i <| instructions profile meta)
            }


instructions :
    Types.Profile
    -> Types.Meta
    -> Nonempty ( ExpModel.Node, ( Intro.Position, Html.Html AppMsg.Msg ) )
instructions profile meta =
    let
        trainingDetails =
            case Lifecycle.state meta profile of
                Lifecycle.Training _ ->
                    [ ( ExpModel.Title
                      , ( Intro.Right, Html.p [] Strings.expInstructionsTraining )
                      )
                    , ( ExpModel.Progress
                      , ( Intro.Left
                        , Html.p []
                            [ Html.text <|
                                Strings.expInstructionsRealStart meta.trainingWork
                            ]
                        )
                      )
                    ]

                _ ->
                    []

        rewriteWithBonus =
            case profile.prolificId of
                Just _ ->
                    Html.div []
                        [ jabberwockyVersion meta Strings.expInstructionsRewrite
                        , Html.p [] [ Html.text Strings.expInstructionsRewriteProlificBonus ]
                        ]

                Nothing ->
                    jabberwockyVersion meta Strings.expInstructionsRewrite
    in
        Nonempty.Nonempty
            ( ExpModel.Title
            , ( Intro.Right, Html.p [] [ Html.text Strings.expInstructionsWelcome ] )
            )
        <|
            [ ( ExpModel.Read
              , ( Intro.Bottom, jabberwockyVersion meta Strings.expInstructionsReadText )
              )
            , ( ExpModel.Task
              , ( Intro.Top, Html.p [] [ Html.text Strings.expInstructionsPause ] )
              )
            , ( ExpModel.Write
              , ( Intro.Right, rewriteWithBonus )
              )
            , ( ExpModel.Tree
              , ( Intro.Left, Html.p [] [ Html.text Strings.expInstructionsSentOther ] )
              )
            , ( ExpModel.Write
              , ( Intro.BottomLeft, jabberwockyVersion meta Strings.expInstructionsTakeTime )
              )
            , ( ExpModel.Images
              , ( Intro.Bottom, Html.p [] [ Html.text Strings.expInstructionsLoop ] )
              )
            , ( ExpModel.Break
              , ( Intro.TopLeft, Html.p [] [ Html.text Strings.expInstructionsBreak ] )
              )
            , ( ExpModel.Images
              , ( Intro.Bottom, Html.p [] Strings.expInstructionsDontInterrupt )
              )
            ]
                ++ trainingDetails


instructionsView :
    (Msg -> AppMsg.Msg)
    -> Types.Profile
    -> Types.Meta
    -> ExpModel.LoadingState
    -> Intro.State ExpModel.Node
    -> List (Html.Html AppMsg.Msg)
instructionsView lift profile meta loading state =
    [ Intro.node
        (instructionsConfig lift profile meta)
        state
        ExpModel.Images
        Html.div
        [ class [ Styles.InstructionImages, Styles.Center ]
        , Attributes.style [ ( "width", "515px" ), ( "height", "351px" ) ]
        ]
        [ Intro.node
            (instructionsConfig lift profile meta)
            state
            ExpModel.Read
            Html.div
            [ Attributes.style [ ( "top", "0" ), ( "left", "140px" ) ]
            , class [ Styles.SmoothAppearing ]
            , classList [ ( Styles.Hidden, Intro.isUnseen ExpModel.Read state ) ]
            ]
            [ Html.img
                [ Attributes.src <|
                    jabberwockyVersion meta Strings.imgPathInstructionsRead
                ]
                []
            ]
        , Intro.node
            (instructionsConfig lift profile meta)
            state
            ExpModel.Task
            Html.div
            [ Attributes.style [ ( "top", "85px" ), ( "left", "70px" ) ]
            , class [ Styles.SmoothAppearing ]
            , classList [ ( Styles.Hidden, Intro.isUnseen ExpModel.Task state ) ]
            ]
            [ Html.img [ Attributes.src Strings.imgPathInstructionsTask ] [] ]
        , Intro.node
            (instructionsConfig lift profile meta)
            state
            ExpModel.Write
            Html.div
            [ Attributes.style [ ( "top", "130px" ), ( "left", "0" ) ]
            , class [ Styles.SmoothAppearing ]
            , classList [ ( Styles.Hidden, Intro.isUnseen ExpModel.Write state ) ]
            ]
            [ Html.img
                [ Attributes.src <|
                    jabberwockyVersion meta Strings.imgPathInstructionsWrite
                ]
                []
            ]
        , Intro.node
            (instructionsConfig lift profile meta)
            state
            ExpModel.Tree
            Html.div
            [ Attributes.style [ ( "top", "150px" ), ( "left", "330px" ) ]
            , class [ Styles.SmoothAppearing ]
            , classList [ ( Styles.Hidden, Intro.isUnseen ExpModel.Tree state ) ]
            ]
            [ Html.img
                [ Attributes.src Strings.imgPathInstructionsTree
                , Attributes.style [ ( "width", "180px" ) ]
                ]
                []
            ]
        , Intro.node
            (instructionsConfig lift profile meta)
            state
            ExpModel.Break
            Html.div
            [ Attributes.style [ ( "top", "247px" ), ( "left", "60px" ) ]
            , class [ Styles.SmoothAppearing ]
            , classList [ ( Styles.Hidden, Intro.isUnseen ExpModel.Break state ) ]
            ]
            [ Html.img
                [ Attributes.src Strings.imgPathInstructionsBreak
                , Attributes.style [ ( "width", "237px" ) ]
                ]
                []
            ]
        ]
    , Html.div
        [ class [ Styles.Center, Styles.CenterText, Styles.SmoothAppearing ]
        , classList [ ( Styles.Hidden, Intro.isRunning state ) ]
        ]
        [ Html.h2 [] [ Html.text "Ready to go?" ]
        , Helpers.evButton
            [ Attributes.disabled (loading /= ExpModel.Loaded)
            , class [ Styles.Btn ]
            ]
            (lift InstructionsStart)
            "Replay instructions"
        , Helpers.evLoadingButton
            loading
            [ class [ Styles.Btn, Styles.BtnPrimary ]
            , id Styles.CtrlNext
            , Helpers.tooltip Strings.pressCtrlEnter
            ]
            (lift LoadTrial)
            ( "Start", "Start", "Searching for sentences" )
        ]
    , Intro.overlay state
    ]



-- BODY AND PROGRESS


progress :
    (Msg -> AppMsg.Msg)
    -> Types.Profile
    -> Types.Meta
    -> ExpModel.Model
    -> List (Html.Html AppMsg.Msg)
progress lift profile meta model =
    let
        widthStyle completed total =
            Attributes.style
                [ ( "width"
                  , (toString <| 100 * (toFloat completed) / (toFloat total)) ++ "%"
                  )
                ]

        contents =
            case Lifecycle.state meta profile of
                Lifecycle.Training _ ->
                    [ Html.text
                        ("Completed "
                            ++ (toString profile.reformulationsCounts.training)
                            ++ " / "
                            ++ (toString meta.trainingWork)
                            ++ " training texts"
                        )
                    , Html.div
                        [ class [ Styles.Bar ]
                        , widthStyle profile.reformulationsCounts.training
                            meta.trainingWork
                        ]
                        []
                    ]

                Lifecycle.Experiment _ ->
                    [ Html.text
                        ("Completed "
                            ++ (toString profile.reformulationsCounts.experiment)
                            ++ " / "
                            ++ (toString meta.experimentWork)
                            ++ " texts"
                        )
                    , Html.div
                        [ class [ Styles.Bar ]
                        , widthStyle profile.reformulationsCounts.experiment
                            meta.experimentWork
                        ]
                        []
                    ]

                Lifecycle.Done ->
                    []
    in
        [ Intro.node
            (instructionsConfig lift profile meta)
            (ExpModel.instructionsState model)
            ExpModel.Progress
            Html.div
            [ class [ Styles.Meta, Styles.Wide ] ]
            [ Html.div [ class [ Styles.Progress ] ] contents ]
        ]


contents :
    (Msg -> AppMsg.Msg)
    -> Types.Profile
    -> Types.Meta
    -> Model
    -> ( Html.Html AppMsg.Msg, List (Html.Html AppMsg.Msg) )
contents lift profile meta model =
    let
        expOrTrainingView =
            case model.experiment.state of
                ExpModel.JustFinished ->
                    ( Html.div [ class [ Styles.SuperNarrow ] ]
                        [ Html.div []
                            [ Html.h3 [] [ Html.text Strings.expTrainingFinishedTitle ]
                            , Html.p [] Strings.expTrainingFinishedExpStarts
                            , Html.p []
                                [ Helpers.evLoadingButton
                                    model.experiment.loadingNext
                                    [ class [ Styles.Btn, Styles.BtnWarning ]
                                    , id Styles.CtrlNext
                                    ]
                                    (lift LoadTrial)
                                    ( "On to the Experiment", "On to the Experiment", "Searching for sentences" )
                                ]
                            ]
                        ]
                    , []
                    )

                ExpModel.Instructions introState ->
                    ( Html.div [ class [ Styles.Normal ] ]
                        [ Html.div [] <|
                            instructionsView lift profile meta model.experiment.loadingNext introState
                        ]
                    , progress lift profile meta model.experiment
                    )

                ExpModel.Trial trialModel ->
                    ( Html.div [ class [ Styles.Narrow ] ]
                        [ Html.div [ class [ Styles.Trial ] ]
                            (trial lift model trialModel)
                        ]
                    , progress lift profile meta model.experiment
                    )

        finishProfileView =
            ( Html.div [ class [ Styles.SuperNarrow ] ]
                [ Html.div []
                    [ Html.h3 [] [ Html.text Strings.expTrainingFinishedTitle ]
                    , Html.p [] [ Html.text Strings.expTrainingFinishedCompleteProfile ]
                    , Html.p []
                        [ Helpers.navA
                            [ class [ Styles.Btn, Styles.BtnPrimary ] ]
                            (Router.Profile Router.Dashboard)
                            "Complete your Profile"
                        ]
                    ]
                ]
            , []
            )

        uncompletableView =
            ( Html.div [ class [ Styles.SuperNarrow ] ]
                [ Html.div []
                    ((Html.h3 [] [ Html.text Strings.expUncompletableTitle ])
                        :: Strings.expUncompletableExplanation
                    )
                ]
            , []
            )
    in
        case Lifecycle.state meta profile of
            Lifecycle.Experiment tests ->
                if List.length tests == 0 then
                    if Lifecycle.stateIsCompletable meta profile then
                        expOrTrainingView
                    else
                        uncompletableView
                else
                    finishProfileView

            Lifecycle.Training _ ->
                if Lifecycle.stateIsCompletable meta profile then
                    expOrTrainingView
                else
                    uncompletableView

            Lifecycle.Done ->
                ( Html.div [ class [ Styles.SuperNarrow ] ]
                    [ Html.div []
                        ((Html.h3 [] [ Html.text Strings.expDone ])
                            :: (Common.prolificCompletion profile)
                            ++ Strings.expDoneReadAbout
                        )
                    ]
                , []
                )



-- TRIAL


trial : (Msg -> AppMsg.Msg) -> Model -> ExpModel.TrialModel -> List (Html.Html AppMsg.Msg)
trial lift model trialModel =
    case trialModel.state of
        ExpModel.Reading ->
            [ Html.div [ class [ Styles.Header ] ]
                [ Html.h4 [] [ Html.text Strings.expReadMemorize ] ]
            , Html.blockquote
                [ Helpers.onEventPreventMsg "copy" (lift CopyPasteEvent)
                , Helpers.onEventPreventMsg "cut" (lift CopyPasteEvent)
                ]
                [ Html.text trialModel.current.text ]
            ]

        ExpModel.Tasking ->
            [ Html.div [ class [ Styles.Header ] ]
                [ Html.h4 [] [ Html.text Strings.expTask ] ]
            ]

        ExpModel.Writing form ->
            [ Html.div [ class [ Styles.Header ] ]
                [ Html.span [ class [ Styles.Clock ] ] [ Clock.view trialModel.clock ]
                , Html.h4 [] [ Html.text Strings.expWrite ]
                ]
            , write lift model form
            ]

        ExpModel.Timeout ->
            [ Html.h3 [] [ Html.text Strings.expTimeoutTitle ]
            , Html.p [] [ Html.text Strings.expTimeoutExplanation ]
            , Html.p []
                [ Helpers.evLoadingButton
                    model.experiment.loadingNext
                    [ class [ Styles.Btn, Styles.BtnPrimary ]
                    , id Styles.CtrlNext
                    ]
                    (lift LoadTrial)
                    ( "Start again", "Start again", "Searching for sentences" )
                ]
            ]

        ExpModel.Standby ->
            [ Html.h3 [] [ Html.text Strings.expStandbyTitle ]
            , Html.p [] [ Html.text Strings.expStandbyExplanation ]
            , Html.p []
                [ Helpers.evLoadingButton
                    model.experiment.loadingNext
                    [ class [ Styles.Btn, Styles.BtnPrimary ]
                    , id Styles.CtrlNext
                    , Helpers.tooltip Strings.pressCtrlEnter
                    ]
                    (lift LoadTrial)
                    ( "Continue", "Continue", "Searching for sentences" )
                ]
            ]


write :
    (Msg -> AppMsg.Msg)
    -> Model
    -> Form.Model String
    -> Html.Html AppMsg.Msg
write lift model { input, feedback, status } =
    Html.form
        [ class [ Styles.FormPage ]
        , Events.onSubmit (lift <| WriteSubmit input)
        , Helpers.onEventPreventMsg "paste" (lift CopyPasteEvent)
        ]
        [ Html.div
            [ class [ Styles.FormBlock ]
            , Helpers.errorStyle "text" feedback
            ]
            [ Autoresize.textarea
                { lift = AppMsg.AutoresizeMsg
                , model = model.autoresize
                , id = toString Styles.InputAutofocus
                , onInput = lift << WriteInput
                }
                [ Attributes.autofocus True
                , Attributes.disabled (status /= Form.Entering)
                ]
                input
            ]
        , feedbackView feedback
        , Html.input
            [ Attributes.type_ "submit"
            , Attributes.disabled (status /= Form.Entering)
            , class [ Styles.Btn, Styles.BtnPrimary ]
            , id Styles.CtrlNext
            , Attributes.value "Send"
            ]
            []
        ]


feedbackView : Feedback.Feedback -> Html.Html AppMsg.Msg
feedbackView feedback =
    let
        original =
            Feedback.getError "text" feedback

        metaContent =
            [ Html.small
                [ class [ Styles.Right, Styles.RevealParentHover ] ]
                [ Helpers.evA [] "#" (AppMsg.CommentMsg CommentMsg.Show) Strings.reportProblem ]
            , Html.img
                [ Attributes.src "/assets/img/instructions-tree-wtf.png"
                , Attributes.style [ ( "width", "150px" ) ]
                , class [ Styles.Right, Styles.RoundBorder ]
                ]
                []
            ]

        content =
            case Helpers.splitFirst ": " original of
                ( "SpellingError", Just mispellings ) ->
                    [ Html.div [] <|
                        metaContent
                            ++ (Strings.expSpellingError mispellings)
                    , Html.div [ class [ Styles.ClearFix ] ] []
                    ]

                ( "PunctuationRepeatedError", Just repeats ) ->
                    [ Html.div [] <|
                        metaContent
                            ++ (Strings.expPunctuationRepeatedError repeats)
                    , Html.div [ class [ Styles.ClearFix ] ] []
                    ]

                ( "PunctuationExcludedError", Just excluded ) ->
                    [ Html.div [] <|
                        metaContent
                            ++ (Strings.expPunctuationExcludedError excluded)
                    , Html.div [ class [ Styles.ClearFix ] ] []
                    ]

                _ ->
                    [ Html.div [] [ Html.p [] [ Html.text original ] ] ]
    in
        Html.div
            [ class [ Styles.RequestBox, Styles.SmoothAppearing ]
            , classList [ ( Styles.Hidden, Feedback.hasError "text" feedback |> not ) ]
            ]
            content
