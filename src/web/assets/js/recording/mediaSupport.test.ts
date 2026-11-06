import { afterEach, describe, expect, it } from "vitest";

import { installFakeMedia, type FakeMedia } from "../test/fakeMedia";
import { isRecordingSupported, MIME_TYPE_CANDIDATES, pickMimeType } from "./mediaSupport";

describe("mediaSupport", () => {
  let media: FakeMedia;

  afterEach(() => media.restore());

  describe("pickMimeType", () => {
    it("prefers MP4 with H.264, which is what Safari records", () => {
      media = installFakeMedia({ supportedTypes: [...MIME_TYPE_CANDIDATES] });

      expect(pickMimeType()).toBe("video/mp4;codecs=avc1.42E01E,mp4a.40.2");
    });

    it("uses plain MP4 when the codecs are not listed as supported", () => {
      media = installFakeMedia({ supportedTypes: ["video/mp4", "video/webm"] });

      expect(pickMimeType()).toBe("video/mp4");
    });

    it("falls back to WebM with VP9, then VP8, then plain WebM", () => {
      media = installFakeMedia({ supportedTypes: ["video/webm;codecs=vp9,opus", "video/webm"] });
      expect(pickMimeType()).toBe("video/webm;codecs=vp9,opus");
      media.restore();

      media = installFakeMedia({ supportedTypes: ["video/webm;codecs=vp8,opus", "video/webm"] });
      expect(pickMimeType()).toBe("video/webm;codecs=vp8,opus");
      media.restore();

      media = installFakeMedia({ supportedTypes: ["video/webm"] });
      expect(pickMimeType()).toBe("video/webm");
    });

    it("returns nothing when no candidate is supported, so the browser chooses", () => {
      media = installFakeMedia({ supportedTypes: [] });

      expect(pickMimeType()).toBeUndefined();
    });

    it("returns nothing when there is no MediaRecorder", () => {
      media = installFakeMedia({ withMediaRecorder: false });

      expect(pickMimeType()).toBeUndefined();
    });
  });

  describe("isRecordingSupported", () => {
    it("is true when the browser has getUserMedia and MediaRecorder", () => {
      media = installFakeMedia();

      expect(isRecordingSupported()).toBe(true);
    });

    it("is false without getUserMedia, as on a page that is not secure", () => {
      media = installFakeMedia({ withMediaDevices: false });

      expect(isRecordingSupported()).toBe(false);
    });

    it("is false without MediaRecorder", () => {
      media = installFakeMedia({ withMediaRecorder: false });

      expect(isRecordingSupported()).toBe(false);
    });
  });
});
