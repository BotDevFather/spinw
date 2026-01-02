import { chromium } from "playwright";
import { spawn } from "child_process";

const HTML_URL = process.env.HTML_URL;
const BOT_TOKEN = process.env.BOT_TOKEN;
const CHAT_ID = process.env.CHAT_ID;

if (!HTML_URL || !BOT_TOKEN || !CHAT_ID) {
  console.error("❌ Missing env vars");
  process.exit(1);
}

(async () => {
  console.log("🌐 Opening:", HTML_URL);

  const browser = await chromium.launch({
    headless: false,
    args: [
    "--kiosk",                  // 🔥 full screen, no UI
    "--no-sandbox",
    "--disable-dev-shm-usage",
    "--disable-infobars",
    "--disable-extensions",
    "--window-position=0,0",
    "--window-size=1080,1080"
  ]
  });

  const page = await browser.newPage({
    viewport: { width: 1080, height: 1080 }
  });

  await page.goto(HTML_URL, { waitUntil: "load" });

  // allow images/fonts to fully load
  await page.waitForTimeout(800);

  console.log("🎥 Starting FFmpeg");

  const ffmpeg = spawn("ffmpeg", [
    "-y",
    "-video_size", "1080x1080",
    "-framerate", "60",
    "-f", "x11grab",
    "-i", ":99.0",
    "-c:v", "libx264",
    "-preset", "veryfast",
    "-pix_fmt", "yuv420p",
    "-movflags", "+faststart",
    "out.mp4"
  ]);

  ffmpeg.stderr.on("data", d => {
    // uncomment for debugging
    // process.stdout.write(d);
  });

  console.log("⏳ Waiting for SPIN_DONE");

  await page.waitForFunction(
    () => window.SPIN_DONE === true,
    null,
    { timeout: 20000 }
  );

  console.log("🛑 Spin done, stopping FFmpeg");

  ffmpeg.stdin.write("q");
  ffmpeg.stdin.end();

  await new Promise(res => ffmpeg.on("close", res));

  await browser.close();

  console.log("📤 Sending video to Telegram");

  const curl = spawn("curl", [
    "-X", "POST",
    `https://api.telegram.org/bot${BOT_TOKEN}/sendVideo`,
    "-F", `chat_id=${CHAT_ID}`,
    "-F", "video=@out.mp4"
  ]);

  await new Promise(res => curl.on("close", res));

  console.log("✅ DONE");
})();
