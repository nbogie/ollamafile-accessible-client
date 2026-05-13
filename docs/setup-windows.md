# Setting up OllamaFile on Windows

This guide walks you through installing and running OllamaFile on a Windows PC. It is written for a first-time user working with a screen reader. Each section is short, with one task per heading. You only do the install once. After that, you start OllamaFile in seconds.

## What OllamaFile is

OllamaFile is a small web page that runs on your own computer and lets you chat with a local AI model. The AI model runs on your PC, not in the cloud, so nothing you type leaves your machine. The page is built to be comfortable with a screen reader: the text box gets focus when the page loads, you press Enter to send, and the assistant's reply is read out by your screen reader as it streams in.

## Step 1: Install Docker Desktop

Docker Desktop is the program that runs OllamaFile and the AI model in the background. Download the installer from the Docker Desktop for Windows download page at https://www.docker.com/products/docker-desktop. Run the installer, accept the defaults, and reboot when it asks you to. After the reboot, open the Start menu, type Docker Desktop, and press Enter to launch it. Wait until Docker Desktop says it is running.

You only do this step once.

## Step 2: Download the OllamaFile folder

You have two ways to get the OllamaFile files onto your PC. Pick whichever you find easier.

The first way is to download a zip from the project's GitHub releases page at https://github.com/nbogie/ollamafile-accessible-client/releases — pick the most recent release, download the Source code (zip), then right-click the downloaded file in File Explorer and choose Extract All. Extract it somewhere easy to find, for example a folder on your desktop called `ollamafile`.

The second way, if you have Git installed, is to open Command Prompt and run:

```
git clone https://github.com/nbogie/ollamafile-accessible-client.git ollamafile
```

Either way, you end up with a folder called `ollamafile` containing all the project files.

## Step 3: Run the first-time setup script

Inside the `ollamafile` folder there is a `scripts` folder, and inside that there is a file called `setup-windows.cmd`. Open File Explorer, navigate into `ollamafile`, then into `scripts`, and press Enter on `setup-windows.cmd`.

The script does six things and tells you what it is doing at each step:

1. Checks that Docker is installed.
2. Checks that Docker Desktop is running.
3. Builds the OllamaFile app and starts the two containers.
4. Downloads the language model. This is the slow part. The default model is about 1.3 gigabytes, so it can take several minutes on a typical home connection.
5. Verifies that the web page is responding on port 5000.
6. Sends a one-word test prompt to confirm the model replies.

If every step succeeds, the script opens http://localhost:5000 in your default browser and creates a desktop shortcut called `Start OllamaFile`. If any step fails, the script stops and tells you what to fix.

You only run the setup script once.

## Step 4: Open the page in your browser

If the setup script did not open it for you, open Microsoft Edge or Google Chrome and type http://localhost:5000 into the address bar, then press Enter. The text box gets focus straight away. Type a message and press Enter to send. The assistant's reply streams into the live region below.

If you want a one-click way to launch OllamaFile from your desktop, the setup script will have already created a desktop shortcut called `Start OllamaFile`. Pressing Enter on it from the desktop will start the containers if they are stopped, and open the web page in your default browser.

## Daily use

Once setup is done, day-to-day use is simple. Press Enter on the `Start OllamaFile` shortcut on your desktop. The shortcut runs `scripts\start-windows.cmd`, which starts the two containers in the background and opens the page in your default browser. Use the page for as long as you like, then close the browser tab when you are finished. The containers keep running in the background, ready for the next time, until you stop them or shut your PC down.

If you prefer the command line, open Command Prompt, change into the `ollamafile` folder, and run `docker compose up -d`. Then open http://localhost:5000 in your browser.

## How to stop OllamaFile

To stop OllamaFile and free up memory, press Enter on `scripts\stop-windows.cmd` from File Explorer. That runs `docker compose down`, which stops both containers cleanly.

If you started OllamaFile with `docker compose up` in a Command Prompt window (without the `-d` flag), you can also stop it by switching back to that Command Prompt window and pressing Ctrl plus C.

## Troubleshooting

This section covers the most common issues. If your problem is not listed, run `docker compose logs app` from inside the `ollamafile` folder. That prints the recent log lines from the OllamaFile app container and usually points at the cause.

### Nothing happens when I press Enter on the script

The most likely cause is that Docker Desktop is not running. Open the Start menu, type Docker Desktop, press Enter, and wait until Docker Desktop says it is running. Then run the script again.

### The setup script says the model download failed

Check that your internet connection is working, then run the setup script again. Docker remembers what was already downloaded, so it picks up where it left off.

### The page in the browser says the site cannot be reached

Run `scripts\start-windows.cmd` to make sure the containers are running. If they were already running, run `docker compose logs app` from inside the `ollamafile` folder to see the error.

### The setup script says port 5000 is already in use

Another program on your PC is using port 5000. The most common culprit on Windows 10 and 11 is Internet Information Services. You can either stop that other program or change OllamaFile's port — open `docker-compose.yml` in Notepad and change `5000:5000` to, for example, `5050:5000`, then re-run the setup script and visit http://localhost:5050 instead.

## Getting help

If you get stuck at any step, copy the messages from the Command Prompt or PowerShell window and send them to Neill. The exact text of the error usually makes the cause obvious.
