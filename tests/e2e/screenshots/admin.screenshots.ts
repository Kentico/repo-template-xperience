import { test } from "@playwright/test";
import { CustomTemplatePage } from "../admin/customTemplatePage";
import { capture } from "../shared/screenshot";

// README screenshots of this repository's administration UI, starting signed in. Replace with the
// library's own pages; drive them through the page objects the tests use.
test("custom UI page template", async ({ page }) => {
  const customTemplate = new CustomTemplatePage(page);

  await customTemplate.goto();
  await customTemplate.clickGetServerTime();
  await customTemplate.expectServerTimeLabel();

  await capture(page, "admin-custom-template", { cropHeight: 400 });
});
