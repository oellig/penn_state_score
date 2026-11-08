#!/usr/bin/env bash
#
# Penn State Score Tracker
# ESPN -> JSON -> GitHub repository
#
# Dependencies: bash, curl, jq, coreutils
#
# Usage:
#   chmod +x psu-score-publish.sh
#   ./psu-score-publish.sh
#

set -Eeuo pipefail

# ============================================================
# CONFIGURATION
# ============================================================

# ESPN configuration
ESPN_URL="https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard"
ESPN_GROUPS="5"
ESPN_LIMIT="100"
PSU_TEAM_ID="213"

# GitHub repository configuration
GITHUB_OWNER="oellig"
GITHUB_REPO="penn_state_score"
GITHUB_BRANCH="main"

# File location inside repository
GITHUB_FILE_PATH="docs/score.json"

# GitHub API configuration
GITHUB_API_URL="https://api.github.com"
GITHUB_TOKEN="insertkeyhere"
GITHUB_PAGES_URL="https://oellig.github.io/penn_state_score/score.json"
# Commit configuration
COMMIT_MESSAGE="Update Penn State scoreboard"

# Temporary working directory
WORK_DIR="/tmp/psu-score-publisher"

# ============================================================
# INITIALIZATION
# ============================================================

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

die() {
    log "ERROR: $*"
    exit 1
}

for cmd in curl jq base64; do
    command -v "$cmd" >/dev/null 2>&1 || die "Missing dependency: $cmd"
done

[[ -n "$GITHUB_TOKEN" ]] || die "GITHUB_TOKEN environment variable is not set"
[[ "$GITHUB_OWNER" != "YOUR_GITHUB_USERNAME" ]] || die "Configure GITHUB_OWNER"
[[ "$GITHUB_REPO" != "YOUR_REPOSITORY" ]] || die "Configure GITHUB_REPO"

mkdir -p "$WORK_DIR"

JSON_FILE="$WORK_DIR/score.json"
RESPONSE_FILE="$WORK_DIR/github-response.json"
PREVIOUS_FILE="$WORK_DIR/previous.json"

# ============================================================
# FETCH ESPN SCOREBOARD
# ============================================================

log "Fetching ESPN scoreboard..."

curl -fsS --retry 3 --retry-delay 2 \
    "${ESPN_URL}?groups=${ESPN_GROUPS}&limit=${ESPN_LIMIT}" \
    -o "$WORK_DIR/espn.json" \
    || die "Unable to retrieve ESPN scoreboard"

# Locate Penn State's game
GAME=$(jq -c --arg id "$PSU_TEAM_ID" '
    [
        .events[]?
        | select(
            any(
                .competitions[0].competitors[]?;
                (.team.id | tostring) == $id
            )
        )
    ][0] // empty
' "$WORK_DIR/espn.json")

# ============================================================
# PROCESS GAME DATA
# ============================================================

if [[ -z "$GAME" ]]; then

    log "No Penn State game found on current scoreboard"

    jq -n '{
        team: "Penn State",
        opponent: null,
        status: "NO_GAME",
        period: null,
        penn_state_score: null,
        opponent_score: null,
        score_difference: null,
        game_id: null,
        event_id: "none",
        event: "NONE",
        scoring_team: null
    }' > "$JSON_FILE"

else

    log "Penn State game found"

    # Extract the game information
    jq --arg id "$PSU_TEAM_ID" '
        . as $game
        |
        (
            $game.competitions[0].competitors
            | map(select((.team.id | tostring) == $id))[0]
        ) as $psu
        |
        (
            $game.competitions[0].competitors
            | map(select((.team.id | tostring) != $id))[0]
        ) as $opp
        |
        {
            team: "Penn State",
            opponent: $opp.team.displayName,
            status: (
                if $game.status.type.state == "pre" then "UPCOMING"
                elif $game.status.type.state == "in" then "IN_PROGRESS"
                elif $game.status.type.state == "post" then "FINAL"
                else "UNKNOWN"
                end
            ),
            period: (
                if ($game.status.period // 0) > 0 then
                    "Q\($game.status.period)"
                else
                    null
                end
            ),
            penn_state_score: ($psu.score | tonumber? // 0),
            opponent_score: ($opp.score | tonumber? // 0),
            score_difference: (
                ($psu.score | tonumber? // 0) -
                ($opp.score | tonumber? // 0)
            ),
            game_id: $game.id
        }
    ' <<< "$GAME" > "$WORK_DIR/game.json"

    # Read previous published JSON, if available.
    # This is also used to identify new scoring events.

    GITHUB_CONTENT_URL="${GITHUB_API_URL}/repos/${GITHUB_OWNER}/${GITHUB_REPO}/contents/${GITHUB_FILE_PATH}"

    HTTP_CODE=$(curl -sS \
        -H "Authorization: Bearer ${GITHUB_TOKEN}" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -G --data-urlencode "ref=${GITHUB_BRANCH}" \
        -o "$RESPONSE_FILE" \
        -w "%{http_code}" \
        "$GITHUB_CONTENT_URL") || die "GitHub read request failed"

    if [[ "$HTTP_CODE" == "200" ]]; then

        EXISTING_SHA=$(jq -r '.sha' "$RESPONSE_FILE")

        jq -r '.content' "$RESPONSE_FILE" |
            tr -d '\n' |
            base64 -d > "$PREVIOUS_FILE" \
            || die "Unable to decode existing GitHub JSON"

    elif [[ "$HTTP_CODE" == "404" ]]; then

        EXISTING_SHA=""
        rm -f "$PREVIOUS_FILE"

    else
        die "GitHub API returned HTTP $HTTP_CODE while reading file"
    fi

    # Determine whether this is a new score event.

    PREVIOUS_GAME=$(jq -r '.game_id // empty' "$PREVIOUS_FILE" 2>/dev/null || true)
    PREVIOUS_PSU=$(jq -r '.penn_state_score // empty' "$PREVIOUS_FILE" 2>/dev/null || true)
    PREVIOUS_OPP=$(jq -r '.opponent_score // empty' "$PREVIOUS_FILE" 2>/dev/null || true)

    CURRENT_GAME=$(jq -r '.game_id' "$WORK_DIR/game.json")
    CURRENT_PSU=$(jq -r '.penn_state_score' "$WORK_DIR/game.json")
    CURRENT_OPP=$(jq -r '.opponent_score' "$WORK_DIR/game.json")

    EVENT="NONE"
    SCORING_TEAM=""

    if [[ "$CURRENT_GAME" == "$PREVIOUS_GAME" ]] &&
       [[ -n "$PREVIOUS_PSU" && -n "$PREVIOUS_OPP" ]] &&
       { [[ "$CURRENT_PSU" != "$PREVIOUS_PSU" ]] ||
         [[ "$CURRENT_OPP" != "$PREVIOUS_OPP" ]]; }; then

        EVENT="SCORE_CHANGED"

        if [[ "$CURRENT_PSU" != "$PREVIOUS_PSU" &&
              "$CURRENT_OPP" != "$PREVIOUS_OPP" ]]; then
            SCORING_TEAM="MULTIPLE"
        elif [[ "$CURRENT_PSU" != "$PREVIOUS_PSU" ]]; then
            SCORING_TEAM="PENN_STATE"
        else
            SCORING_TEAM="OPPONENT"
        fi

    elif [[ -n "$PREVIOUS_FILE" ]] &&
         [[ -f "$PREVIOUS_FILE" ]] &&
         [[ "$CURRENT_GAME" == "$PREVIOUS_GAME" ]]; then

        # Keep an existing event visible until another score occurs.
        EVENT=$(jq -r '.event // "NONE"' "$PREVIOUS_FILE")
        SCORING_TEAM=$(jq -r '.scoring_team // empty' "$PREVIOUS_FILE")

    fi

    # Construct the final JSON document.

    jq --arg event "$EVENT" \
       --arg scoring_team "$SCORING_TEAM" '
        . + {
            event: $event,
            scoring_team: (
                if $scoring_team == "" then null
                else $scoring_team
                end
            ),
            event_id: (
                .game_id + "-" +
                (.penn_state_score | tostring) + "-" +
                (.opponent_score | tostring)
            )
        }
    ' "$WORK_DIR/game.json" > "$JSON_FILE"

fi

# ============================================================
# PREPARE GITHUB UPDATE
# ============================================================

if [[ -f "$PREVIOUS_FILE" ]] &&
   cmp -s "$JSON_FILE" "$PREVIOUS_FILE"; then

    log "Scoreboard unchanged. No GitHub commit required."
    exit 0
fi

log "Preparing GitHub update..."

FILE_CONTENT=$(base64 -w 0 "$JSON_FILE")

# Build API request
if [[ -n "${EXISTING_SHA:-}" ]]; then

    REQUEST=$(jq -n \
        --arg message "$COMMIT_MESSAGE" \
        --arg content "$FILE_CONTENT" \
        --arg branch "$GITHUB_BRANCH" \
        --arg sha "$EXISTING_SHA" \
        '{
            message: $message,
            content: $content,
            branch: $branch,
            sha: $sha
        }')

else

    REQUEST=$(jq -n \
        --arg message "$COMMIT_MESSAGE" \
        --arg content "$FILE_CONTENT" \
        --arg branch "$GITHUB_BRANCH" \
        '{
            message: $message,
            content: $content,
            branch: $branch
        }')

fi

# ============================================================
# PUSH TO GITHUB
# ============================================================

log "Publishing scoreboard to GitHub..."

HTTP_CODE=$(curl -sS \
    -X PUT \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    -H "Content-Type: application/json" \
    -d "$REQUEST" \
    -o "$RESPONSE_FILE" \
    -w "%{http_code}" \
    "$GITHUB_CONTENT_URL") || die "GitHub upload request failed"

if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" ]]; then

    log "Successfully published Penn State scoreboard."

    if [[ -n "${GITHUB_PAGES_URL:-}" ]]; then
        log "Published file: ${GITHUB_PAGES_URL}"
    fi

else

    log "GitHub API response:"
    jq -r '.message // "Unknown error"' "$RESPONSE_FILE" 2>/dev/null || true
    die "GitHub upload failed (HTTP $HTTP_CODE)"

fi
