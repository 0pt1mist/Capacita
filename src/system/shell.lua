-- Capacita Shell v0.1
sys.print("-----------------------------------")
sys.print("Welcome to Capacita OS (PoC)")
sys.print("Type 'help' for commands.")
sys.print("-----------------------------------")

while true do
  local input = sys.readln()
  sys.print("> " .. input)
  
  if input == "help" then
    sys.print("Available capabilities:")
    sys.print("- help : show this message")
    sys.print("- info : system architecture")
    sys.print("- ping : test IPC")
  elseif input == "info" then
    sys.print("OS: Capacita Early Alpha")
    sys.print("Architecture: Zero-ACL, Object-based")
    sys.print("File system: UNAVAILABLE")
    sys.print("Hardware access: ISOLATED")
  elseif input == "ping" then
    sys.print("pong!")
  elseif input == "" then
  else
    sys.print("Unknown engram request: " .. input)
  end
end