module Decoders
    exposing
        ( detail
        , email
        , feedback
        , meta
        , page
        , preUser
        , profile
        , sentence
        , token
        , tree
        , user
        , wordSpan
        )

import Config
import Date
import Dict
import Feedback
import Json.Decode as JD
import Json.Decode.Pipeline as Pipeline
import Maybe.Extra exposing ((?))
import Regex
import Types


token : JD.Decoder String
token =
    JD.at [ "key" ] JD.string


detail : JD.Decoder String
detail =
    JD.at [ "detail" ] JD.string


preUser : JD.Decoder Types.PreUser
preUser =
    Pipeline.decode Types.PreUser
        |> Pipeline.required "id" JD.int
        |> Pipeline.required "username" JD.string
        |> Pipeline.required "is_active" JD.bool
        |> Pipeline.required "is_staff" JD.bool
        |> Pipeline.required "profile" (JD.nullable profile)
        |> Pipeline.required "emails" (JD.list email)


user : JD.Decoder Types.User
user =
    Pipeline.decode Types.User
        |> Pipeline.required "id" JD.int
        |> Pipeline.required "username" JD.string
        |> Pipeline.required "is_active" JD.bool
        |> Pipeline.required "is_staff" JD.bool
        |> Pipeline.required "profile" profile
        |> Pipeline.required "emails" (JD.list email)


profile : JD.Decoder Types.Profile
profile =
    Pipeline.decode Types.Profile
        |> Pipeline.required "id" JD.int
        |> Pipeline.required "created" date
        |> Pipeline.required "prolific_id" (JD.nullable JD.string)
        |> Pipeline.required "mothertongue" JD.string
        |> Pipeline.required "trained_reformulations" JD.bool
        |> Pipeline.required "introduced_exp_home" JD.bool
        |> Pipeline.required "introduced_exp_play" JD.bool
        |> Pipeline.required "user" JD.int
        |> Pipeline.required "questionnaire" (JD.nullable JD.int)
        |> Pipeline.required "word_span" (JD.nullable JD.int)
        |> Pipeline.required "comments" (JD.list JD.int)
        |> Pipeline.required "sentences" (JD.list JD.int)
        |> Pipeline.required "trees" (JD.list JD.int)
        |> Pipeline.required "user_username" JD.string
        |> Pipeline.required "reformulations_counts" bucketCounts
        |> Pipeline.required "available_trees_counts" bucketCounts


bucketCounts : JD.Decoder Types.BucketCounts
bucketCounts =
    Pipeline.decode Types.BucketCounts
        |> Pipeline.required "training" JD.int
        |> Pipeline.required "experiment" JD.int


date : JD.Decoder Date.Date
date =
    let
        fromString string =
            case Date.fromString string of
                Err err ->
                    JD.fail err

                Ok date ->
                    JD.succeed date
    in
        JD.string
            |> JD.andThen fromString


email : JD.Decoder Types.Email
email =
    Pipeline.decode Types.Email
        |> Pipeline.required "id" JD.int
        |> Pipeline.required "email" JD.string
        |> Pipeline.required "verified" JD.bool
        |> Pipeline.required "primary" JD.bool
        |> Pipeline.required "user" JD.int
        |> Pipeline.hardcoded False


feedback : List ( String, String ) -> JD.Decoder Feedback.Feedback
feedback fields =
    let
        checkKnown feedback =
            if Feedback.noKnownErrors feedback then
                JD.fail ("Unknown errors: " ++ (Feedback.getUnknown feedback))
            else
                JD.succeed feedback
    in
        JD.oneOf [ JD.string, JD.index 0 JD.string ]
            |> JD.dict
            |> JD.map (toFeedback <| Dict.fromList fields)
            |> JD.andThen checkKnown


toFeedback : Dict.Dict String String -> Dict.Dict String String -> Feedback.Feedback
toFeedback fields feedbackItems =
    let
        ( known, unknown ) =
            Dict.partition (\k v -> Dict.member k fields) feedbackItems

        finishFeedback processed =
            Feedback.feedback processed (toString unknown)
    in
        Dict.toList known
            |> List.map (\( k, e ) -> ( (Dict.get k fields) ? k, e ))
            |> Dict.fromList
            |> finishFeedback


wordSpan : JD.Decoder Types.WordSpan
wordSpan =
    Pipeline.decode Types.WordSpan
        |> Pipeline.required "id" JD.int
        |> Pipeline.required "created" date
        |> Pipeline.required "span" JD.int
        |> Pipeline.required "score" JD.int
        |> Pipeline.required "profile" JD.int


page : JD.Decoder a -> JD.Decoder (Types.Page a)
page item =
    Pipeline.decode Types.Page
        |> Pipeline.required "count" JD.int
        |> Pipeline.required "results" (JD.list item)


choice : JD.Decoder Types.Choice
choice =
    Pipeline.decode Types.Choice
        |> Pipeline.required "name" JD.string
        |> Pipeline.required "label" JD.string


meta : JD.Decoder Types.Meta
meta =
    let
        versionCheckedMeta parsedVersion =
            if parsedVersion >= Config.minServerVersion then
                JD.succeed Types.Meta
            else
                JD.fail "This JSON is from a deprecated source. Please upgrade!"
    in
        Pipeline.decode versionCheckedMeta
            |> Pipeline.required "version" version
            |> -- Check version before anything else
               Pipeline.resolve
            |> Pipeline.required "target_branch_depth" JD.int
            |> Pipeline.required "target_branch_count" JD.int
            |> Pipeline.required "branch_probability" JD.float
            |> Pipeline.required "read_factor" JD.float
            |> Pipeline.required "write_factor" JD.float
            |> Pipeline.required "min_tokens" JD.int
            |> Pipeline.required "jabberwocky_mode" JD.bool
            |> Pipeline.required "heartbeat" JD.float
            |> Pipeline.required "heartbeat_margin" JD.float
            |> Pipeline.required "gender_choices" (JD.list choice)
            |> Pipeline.required "education_level_choices" (JD.list choice)
            |> Pipeline.required "job_type_choices" (JD.list choice)
            |> Pipeline.hardcoded
                [ { name = "experiment", label = "Experiment" }
                , { name = "training", label = "Training" }
                ]
            |> Pipeline.required "experiment_work" JD.int
            |> Pipeline.required "training_work" JD.int
            |> Pipeline.required "tree_cost" JD.int
            |> Pipeline.required "base_credit" JD.int
            |> Pipeline.required "default_language" JD.string
            |> Pipeline.required "supported_languages" (JD.list choice)
            |> Pipeline.required "other_language" JD.string


version : JD.Decoder ( Int, Int, Int )
version =
    let
        fromString string =
            let
                parts =
                    Regex.split (Regex.AtMost 1) (Regex.regex "\\+|-") string
                        |> List.head
                        |> Maybe.map (String.split ".")
                        |> Maybe.map (List.map String.toInt)
            in
                case parts of
                    Just [ Ok major, Ok minor, Ok patch ] ->
                        JD.succeed ( major, minor, patch )

                    _ ->
                        JD.fail ("Badly formatted version string: \"" ++ string ++ "\"")
    in
        JD.string |> JD.andThen fromString


sentence : JD.Decoder Types.Sentence
sentence =
    Pipeline.decode Types.Sentence
        |> Pipeline.required "id" JD.int
        |> Pipeline.required "created" date
        |> Pipeline.required "text" JD.string
        |> Pipeline.required "language" JD.string
        |> Pipeline.required "bucket" JD.string
        |> Pipeline.required "read_time_proportion" JD.float
        |> Pipeline.required "read_time_allotted" JD.float
        |> Pipeline.required "write_time_proportion" JD.float
        |> Pipeline.required "write_time_allotted" JD.float
        |> Pipeline.required "tree" JD.int
        |> Pipeline.required "profile" JD.int
        |> Pipeline.required "parent" (JD.nullable JD.int)
        |> Pipeline.required "children" (JD.list JD.int)
        |> Pipeline.required "profile_username" JD.string


tree : JD.Decoder Types.Tree
tree =
    Pipeline.decode Types.Tree
        |> Pipeline.required "id" JD.int
        |> Pipeline.required "root" sentence
        |> Pipeline.required "sentences" (JD.list JD.int)
        |> Pipeline.required "profiles" (JD.list JD.int)
        |> Pipeline.required "network_edges" (JD.list (edge JD.int))
        |> Pipeline.required "branches_count" JD.int
        |> Pipeline.required "shortest_branch_depth" JD.int


edge : JD.Decoder a -> JD.Decoder (Types.Edge a)
edge node =
    Pipeline.decode Types.Edge
        |> Pipeline.required "source" node
        |> Pipeline.required "target" node
