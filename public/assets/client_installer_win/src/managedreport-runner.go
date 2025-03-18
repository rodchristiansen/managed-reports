package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"

	"gopkg.in/yaml.v2"
)

type PassphraseConfig struct {
	Passphrase string `yaml:"Passphrase"`
}

func loadPassphrase(path string) string {
	passphrase := ""
	data, err := os.ReadFile(path)
	if err == nil {
		var cfg PassphraseConfig
		if err = yaml.Unmarshal(data, &cfg); err == nil {
			passphrase = cfg.Passphrase
		}
	}
	return passphrase
}

type Config struct {
	BaseURL string   `json:"BaseURL"`
	Token   string   `json:"Token"`
	Scripts []string `json:"Scripts"`
}

func loadConfig(path string) (Config, error) {
	var cfg Config
	file, err := os.Open(path)
	if err != nil {
		return cfg, err
	}
	defer file.Close()

	decoder := json.NewDecoder(file)
	err = decoder.Decode(&cfg)
	return cfg, err
}

func runScript(scriptPath string, cachePath string) error {
	cmd := exec.Command("powershell.exe", "-ExecutionPolicy", "Bypass", "-File", scriptPath)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return err
	}
	return ioutil.WriteFile(cachePath, output, 0644)
}

func postReport(cfg Config, serialNumber string, module string, data []byte, baseDir string) error {
	postURL := cfg.BaseURL + "report/check_in/"

	passphrase := loadPassphrase(filepath.Join(baseDir, "config", "passphrase.yaml"))

	payload := map[string]string{
		"serial_number": serialNumber,
		"platform":      "windows",
		"module":        module,
		"data":          string(data),
	}

	if passphrase != "" {
		payload["passphrase"] = passphrase
	}

	payloadBytes, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	req, err := http.NewRequest("POST", postURL, bytes.NewBuffer(payloadBytes))
	req.Header.Set("Authorization", "Bearer "+cfg.Token)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := ioutil.ReadAll(resp.Body)
		return fmt.Errorf("HTTP Error: %s - %s", resp.Status, string(body))
	}

	return nil
}

func main() {
	baseDir := "C:\\ProgramData\\ManagedReporting"

	logFile, err := os.OpenFile(filepath.Join(baseDir, "logs", "reporting.log"), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err != nil {
		log.Fatalf("Unable to open log file: %v", err)
	}
	log.SetOutput(logFile)
	defer logFile.Close()

	configPath := filepath.Join(baseDir, "config", "preferences.json")
	cfg, err := loadConfig(configPath)
	if err != nil {
		log.Fatalf("Failed to load configuration: %v", err)
	}

	serialNumberCmd := exec.Command("powershell.exe", "-Command", "(Get-WmiObject Win32_BIOS).SerialNumber")
	serialNumberRaw, err := serialNumberCmd.Output()
	if err != nil {
		log.Fatalf("Failed to get serial number: %v", err)
	}
	serialNumber := string(bytes.TrimSpace(serialNumberRaw))

	for _, script := range []string{"hardware.ps1", "software.ps1"} {
		scriptPath := filepath.Join(baseDir, "scripts", script)
		cacheFile := filepath.Join(baseDir, "cache", script[:len(script)-4]+".json")

		err := runScript(scriptPath, cacheFile)
		if err != nil {
			log.Printf("Failed running script %s: %v", script, err)
			continue
		}

		data, err := ioutil.ReadFile(cacheFile)
		if err != nil {
			log.Printf("Failed reading cache for %s: %v", script, err)
			continue
		}

		err = postReport(cfg, serialNumber, script, data, baseDir)
		if err != nil {
			log.Printf("Failed posting %s data: %v", script, err)
			continue
		}

		log.Printf("Successfully reported %s data.", script)
	}
}
