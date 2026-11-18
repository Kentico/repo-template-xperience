import { expect, test } from "@playwright/test";
import { capture } from "../shared/screenshot";

// README screenshots of the live site. Replace with the pages, widgets, or sections this repository's
// library adds. Content they need belongs in the CI repository, so every database has it.
test("live site", async ({ page }) => {
  const response = await page.goto("/");
  expect(response?.status()).toBe(200);
  await expect(page.getByRole("heading", { level: 1 })).toBeVisible();

  await capture(page, "live-site-home", { fullHeight: 6000 });
});
