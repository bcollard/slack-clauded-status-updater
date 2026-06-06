package status_rotator

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand/v2"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/GoogleCloudPlatform/functions-framework-go/functions"
)

func init() {
	functions.HTTP("RotateStatus", rotateStatus)
}

func rotateStatus(w http.ResponseWriter, r *http.Request) {
	token := strings.TrimSpace(os.Getenv("SLACK_TOKEN"))
	if token == "" {
		http.Error(w, "SLACK_TOKEN env var is empty", http.StatusInternalServerError)
		return
	}

	emoji := os.Getenv("STATUS_EMOJI")
	if emoji == "" {
		emoji = ":brain:"
	}

	word := words[rand.IntN(len(words))]

	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()

	if err := setStatus(ctx, token, word, emoji); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}

	fmt.Fprintf(w, "status set to %q %s\n", word, emoji)
}

func setStatus(ctx context.Context, token, text, emoji string) error {
	body, err := json.Marshal(map[string]any{
		"profile": map[string]any{
			"status_text":       text,
			"status_emoji":      emoji,
			"status_expiration": 0,
		},
	})
	if err != nil {
		return fmt.Errorf("marshal body: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		"https://slack.com/api/users.profile.set", strings.NewReader(string(body)))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json; charset=utf-8")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("slack call: %w", err)
	}
	defer resp.Body.Close()

	var sr struct {
		OK    bool   `json:"ok"`
		Error string `json:"error"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&sr); err != nil {
		return fmt.Errorf("decode slack response: %w", err)
	}
	if !sr.OK {
		return fmt.Errorf("slack api error: %s", sr.Error)
	}
	return nil
}
