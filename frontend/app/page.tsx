"use client";

import { useState, type FormEvent } from "react";
import { createLink, type LinkResult } from "@/lib/api";

export default function Home() {
  const [url, setUrl] = useState("");
  const [result, setResult] = useState<LinkResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [copied, setCopied] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setResult(null);
    setCopied(false);
    setLoading(true);
    try {
      setResult(await createLink(url.trim()));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setLoading(false);
    }
  }

  async function copy() {
    if (!result) return;
    await navigator.clipboard.writeText(result.short_url);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center px-4 py-12">
      <h1 className="text-3xl font-bold tracking-tight">Shorten a link</h1>
      <p className="mt-2 text-sm text-gray-500">
        Paste a long URL and get a short one. Links expire after 90 days.
      </p>

      <form onSubmit={onSubmit} className="mt-8 flex flex-col gap-3 sm:flex-row">
        <input
          type="text"
          inputMode="url"
          value={url}
          onChange={(e) => setUrl(e.target.value)}
          placeholder="https://example.com/a/very/long/link"
          aria-label="URL to shorten"
          className="flex-1 rounded-lg border border-gray-300 bg-transparent px-4 py-2.5 outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-500/30"
          required
        />
        <button
          type="submit"
          disabled={loading || !url.trim()}
          className="rounded-lg bg-blue-600 px-5 py-2.5 font-medium text-white transition hover:bg-blue-700 disabled:cursor-not-allowed disabled:opacity-50"
        >
          {loading ? "Shortening…" : "Shorten"}
        </button>
      </form>

      {error && (
        <p role="alert" className="mt-4 rounded-lg border border-red-300 bg-red-50 px-4 py-3 text-sm text-red-700">
          {error}
        </p>
      )}

      {result && (
        <div className="mt-6 rounded-lg border border-gray-300 p-4">
          <p className="text-xs uppercase tracking-wide text-gray-500">Your short link</p>
          <div className="mt-2 flex items-center justify-between gap-3">
            <a
              href={result.short_url}
              target="_blank"
              rel="noopener noreferrer"
              className="break-all font-medium text-blue-600 hover:underline"
            >
              {result.short_url}
            </a>
            <button
              onClick={copy}
              className="shrink-0 rounded-md border border-gray-300 px-3 py-1.5 text-sm hover:bg-gray-100 dark:hover:bg-gray-800"
            >
              {copied ? "Copied!" : "Copy"}
            </button>
          </div>
          <p className="mt-3 truncate text-xs text-gray-500">Original: {result.long_url}</p>
        </div>
      )}
    </main>
  );
}