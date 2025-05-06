package main

import (
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v2"
)

const (
	baseDir = `C:\ProgramData\ManagedReporting`
)

// --------------------------------------------------------------------
// Config helpers
// --------------------------------------------------------------------
type passphraseCfg struct {
	Passphrase string `yaml:"Passphrase"`
}

func loadPassphrase(path string) string {
	b, _ := os.ReadFile(path)
	var cfg passphraseCfg
	if yaml.Unmarshal(b, &cfg) == nil {
		return cfg.Passphrase
	}
	return ""
}

type Config struct {
	BaseURL string   `json:"BaseURL"`
	Token   string   `json:"Token"`
	Scripts []string `json:"Scripts"` // optional override
}

func loadConfig(path string) (Config, error) {
	f, err := os.Open(path)
	if err != nil {
		return Config{}, err
	}
	defer f.Close()
	var c Config
	err = json.NewDecoder(f).Decode(&c)
	return c, err
}

// --------------------------------------------------------------------
// Script execution
// --------------------------------------------------------------------
func runScript(path string) ([]byte, error) {
	cmd := exec.Command("powershell.exe",
		"-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
		"-File", path)
	return cmd.CombinedOutput()
}

// --------------------------------------------------------------------
// POST helpers
// --------------------------------------------------------------------
func postReport(cfg Config, module string, data []byte, verbose bool) error {
	url := strings.TrimRight(cfg.BaseURL, "/") + "/submit/" + module

	req, err := http.NewRequest("POST", url, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+cfg.Token)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	if verbose {
		log.Printf("→ %s %s\n%s", module, resp.Status, body)
	}
	if resp.StatusCode >= 300 {
		return fmt.Errorf("submit %s → %s: %s", module, resp.Status, body)
	}
	return nil
}

// --------------------------------------------------------------------
// Main
// --------------------------------------------------------------------
func main() {
	// --- CLI flags ---------------------------------------------------
	verbose := flag.Bool("v", false, "log to console as well as file")
	flag.Parse()
	// ----- bootstrap -------------------------------------------------
	if err := os.MkdirAll(filepath.Join(baseDir, "logs"), 0755); err != nil {
		log.Fatalf("mkdir logs: %v", err)
	}
	logFile, err := os.OpenFile(
		filepath.Join(baseDir, "logs", "reporting.log"),
		os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		log.Fatalf("open log: %v", err)
	}
	defer logFile.Close()
	if *verbose {
		log.SetOutput(io.MultiWriter(os.Stdout, logFile))
	} else {
		log.SetOutput(logFile)
	}

	cfg, err := loadConfig(filepath.Join(baseDir, "config", "preferences.json"))
	if err != nil {
		log.Fatalf("load config: %v", err)
	}

	serialCmd := exec.Command("powershell.exe",
		"-NoProfile", "-NonInteractive", "-Command",
		"(Get-CimInstance -ClassName Win32_Bios).SerialNumber.Trim()")
	serialRaw, err := serialCmd.Output()
	if err != nil {
		log.Fatalf("serial: %v", err)
	}
	serial := string(bytes.TrimSpace(serialRaw))

	// default script list when not overridden in preferences.json
	scriptMap := map[string]string{
		"hardware.ps1":        "machine_win",
		"software.ps1":        "applications_win",
		"managedinstalls.ps1": "managedinstalls_win",
	}
	if len(cfg.Scripts) == 0 {
		cfg.Scripts = []string{"hardware.ps1", "software.ps1", "managedinstalls.ps1"}
	}

	passphrase := loadPassphrase(filepath.Join(baseDir, "config", "passphrase.yaml"))

	// ----- execute + submit -----------------------------------------
	for _, script := range cfg.Scripts {
		scriptPath := filepath.Join(baseDir, "scripts", script)

		payload, err := runScript(scriptPath)
		if err != nil {
			log.Printf("run %s: %v", script, err)
			continue
		}

		// inject serial_number / passphrase if the script didn’t add them
		var m map[string]interface{}
		if json.Unmarshal(payload, &m) == nil {
			m["serial_number"] = serial
			if passphrase != "" {
				m["passphrase"] = passphrase
			}
			if patched, err := json.Marshal(m); err == nil {
				payload = patched
			}
		}

		mod := scriptMap[script]
		if mod == "" {
			log.Printf("skip %s – unknown module", script)
			continue
		}

		if err := postReport(cfg, mod, payload, *verbose); err != nil {
			log.Printf("submit %s: %v", script, err)
			continue
		}
		log.Printf("✓ %s → %s", script, mod)
	}
}
