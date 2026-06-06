is there a way to automatically update my slack status with funky words taken from claude code "thinking mode" as in the following:
Accomplishing, Actioning, Actualizing, Architecting, Baking, Beaming, Beboppin', Befuddling, Billowing, Blanching, Bloviating, Boogieing, Boondoggling, Booping, Bootstrapping, Brewing, Bunning, Burrowing, Calculating, Canoodling, Caramelizing, Cascading, Catapulting, Cerebrating, Channeling, Channelling, Choreographing, Churning, Clauding, Coalescing, Cogitating, Combobulating, Composing, Computing, Concocting, Considering, Contemplating, Cooking, Crafting, Creating, Crunching, Crystallizing, Cultivating, Deciphering, Deliberating, Determining, Dilly-dallying, Discombobulating, Doing, Doodling, Drizzling, Ebbing, Effecting, Elucidating, Embellishing, Enchanting, Envisioning, Evaporating, Fermenting, Fiddle-faddling, Finagling, Flambéing, Flibbertigibbeting, Flowing, Flummoxing, Fluttering, Forging, Forming, Frolicking, Frosting, Gallivanting, Galloping, Garnishing, Generating, Gesticulating, Germinating, Gitifying, Grooving, Gusting, Harmonizing, Hashing, Hatching, Herding, Honking, Hullaballooing, Hyperspacing, Ideating, Imagining, Improvising, Incubating, Inferring, Infusing, Ionizing, Jitterbugging, Julienning, Kneading, Leavening, Levitating, Lollygagging, Manifesting, Marinating, Meandering, Metamorphosing, Misting, Moonwalking, Moseying, Mulling, Mustering, Musing, Nebulizing, Nesting, Newspapering, Noodling, Nucleating, Orbiting, Orchestrating, Osmosing, Perambulating, Percolating, Perusing, Philosophising, Photosynthesizing, Pollinating, Pondering, Pontificating, Pouncing, Precipitating, Prestidigitating, Processing, Proofing, Propagating, Puttering, Puzzling, Quantumizing, Razzle-dazzling, Razzmatazzing, Recombobulating, Reticulating, Roosting, Ruminating, Sautéing, Scampering, Schlepping, Scurrying, Seasoning, Shenaniganing, Shimmying, Simmering, Skedaddling, Sketching, Slithering, Smooshing, Sock-hopping, Spelunking, Spinning, Sprouting, Stewing, Sublimating, Swirling, Swooping, Symbioting, Synthesizing, Tempering, Thinking, Thundering, Tinkering, Tomfoolering, Topsy-turvying, Transfiguring, Transmuting, Twisting, Undulating, Unfurling, Unravelling, Vibing, Waddling, Wandering, Warping, Whatchamacalliting, Whirlpooling, Whirring, Whisking, Wibbling, Working, Wrangling, Zesting, Zigzagging
..
without installed a custom app in slack? or at least without admin roles or right on my slack workspace? maybe with a command or a bot or something else?

Show more
19 May

Searched the web
Searched the web
Good news — here's the full picture:

TL;DR: Yes, you can do this without admin rights, but you do need to create a personal Slack app (which any member can do — it's free and doesn't require workspace admin approval when you only install it for yourself).

What you need
You update your own Slack status using your personal user token (xoxp-) with the users.profile.set API method and the users.profile:write scope. No admin role needed — you're just acting on your own account. 
Slack

For internal apps used in a single workspace, you can use the simple "Install to Workspace" button in the OAuth & Permissions page — this generates tokens instantly without implementing a full OAuth flow. 
Suptask

Step-by-step setup
1. Create a Slack app (5 min, no admin needed)

Go to api.slack.com/apps → Create New App → From scratch
Name it anything (e.g. "My Status Rotator")
Select your workspace
2. Add the right scope

Go to OAuth & Permissions → scroll to User Token Scopes
Add: users.profile:write
3. Install it to your workspace

Click Install to Workspace — this only installs it for you, not the whole org
Copy the User OAuth Token (starts with xoxp-)
4. Run a script that rotates the status

Here's a simple shell script you can run as a cron job or on demand:

bash
#!/bin/bash

WORDS=(
  "Accomplishing" "Beboppin'" "Boondoggling" "Brewing" "Canoodling"
  "Cerebrating" "Discombobulating" "Dilly-dallying" "Flibbertigibbeting"
  "Gallivanting" "Hullaballooing" "Lollygagging" "Moonwalking" "Noodling"
  "Osmosing" "Prestidigitating" "Razzmatazzing" "Recombobulating"
  "Reticulating" "Shenaniganing" "Spelunking" "Topsy-turvying" "Wibbling"
  # add as many as you want...
)

SLACK_TOKEN="xoxp-your-token-here"
RANDOM_WORD=${WORDS[$RANDOM % ${#WORDS[@]}]}

curl -s -X POST "https://slack.com/api/users.profile.set" \
  -H "Authorization: Bearer $SLACK_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"profile\": {\"status_text\": \"$RANDOM_WORD\", \"status_emoji\": \":brain:\", \"status_expiration\": 0}}"

echo "Status set to: $RANDOM_WORD"
5. Schedule it (optional)

To rotate every 30 minutes automatically, add to crontab (crontab -e):

*/30 * * * * /path/to/your/script.sh
Alternatives if you can't create apps
Zapier / Make (formerly Integromat): both have native Slack "Set Status" actions and can run on a timer — no coding required, but they do use OAuth which still requires a one-time app auth
n8n: you already have it connected — you could build a workflow there that rotates your status on a schedule, no Slack app needed if you authenticate via their Slack node
The n8n route might actually be the smoothest for you since it's already in your toolbox. Want me to sketch out how that workflow would look?

...


instead of n8n, what would be the equivalent in google cloud?

19 May
You have a few options depending on how much infrastructure you want to touch. The cleanest equivalent to n8n's 3-node setup is Cloud Scheduler + Cloud Functions:



Here's the full setup:

The 3 GCP services you need:

Cloud Scheduler — the cron trigger (replaces n8n's Schedule node)
Cloud Functions — the code that runs (replaces n8n's Code + HTTP Request nodes combined)
Secret Manager — stores your xoxp- token securely (optional but recommended)
Step 1 — Write the function

Create a file main.py (or index.js if you prefer Node):

python
import random
import requests
from google.cloud import secretmanager

WORDS = [
    "Beboppin'", "Boondoggling", "Canoodling", "Cerebrating",
    "Discombobulating", "Flibbertigibbeting", "Gallivanting",
    "Hullaballooing", "Lollygagging", "Moonwalking", "Noodling",
    "Prestidigitating", "Razzmatazzing", "Recombobulating",
    "Reticulating", "Shenaniganing", "Spelunking", "Wibbling",
    # add the full list...
]

def rotate_status(request):
    client = secretmanager.SecretManagerServiceClient()
    name = "projects/YOUR_PROJECT_ID/secrets/slack-token/versions/latest"
    token = client.access_secret_version(name=name).payload.data.decode("utf-8")

    word = random.choice(WORDS)
    requests.post(
        "https://slack.com/api/users.profile.set",
        headers={"Authorization": f"Bearer {token}"},
        json={"profile": {"status_text": word, "status_emoji": ":brain:", "status_expiration": 0}}
    )
    return f"Status set to: {word}", 200
And a requirements.txt:

requests
google-cloud-secret-manager
Step 2 — Deploy

bash
gcloud functions deploy rotate-slack-status \
  --runtime python311 \
  --trigger-http \
  --no-allow-unauthenticated \
  --region europe-west1
Step 3 — Store your token in Secret Manager

bash
echo -n "xoxp-your-token-here" | \
  gcloud secrets create slack-token --data-file=-
Then grant the function's service account access to it:

bash
gcloud secrets add-iam-policy-binding slack-token \
  --member="serviceAccount:YOUR_PROJECT@appspot.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
Step 4 — Create the scheduler job

bash
gcloud scheduler jobs create http slack-status-rotator \
  --schedule="*/30 * * * *" \
  --uri="https://REGION-PROJECT_ID.cloudfunctions.net/rotate-slack-status" \
  --oidc-service-account-email="YOUR_PROJECT@appspot.gserviceaccount.com" \
  --time-zone="Europe/Paris"
The --no-allow-unauthenticated + --oidc-service-account-email combo means only your scheduler can trigger the function — nothing else can call it from the internet.

Cost: essentially zero. Both Cloud Functions and Cloud Scheduler have generous free tiers — 2M function invocations and 3 scheduler jobs per month free. This workflow uses maybe 1,440 invocations/month at 30-min intervals.