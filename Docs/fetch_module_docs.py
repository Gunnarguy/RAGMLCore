import json
import os
import sys
import urllib.error
import urllib.request

BASE_URL = "https://developer.apple.com/tutorials/data"


def fetch_module(module: str, dest_root: str, limit: int | None = None) -> None:
    os.makedirs(dest_root, exist_ok=True)
    queue = [f"documentation/{module}"]
    visited: set[str] = set()

    while queue:
        path = queue.pop(0)
        if path in visited:
            continue
        visited.add(path)
        if limit is not None and len(visited) > limit:
            print(f"Reached limit ({limit}) for {module}; stopping.")
            break

        url = f"{BASE_URL}/{path}.json"
        try:
            with urllib.request.urlopen(url) as response:
                data = json.load(response)
        except urllib.error.HTTPError as err:
            print(f"HTTPError {err.code} {url}")
            continue
        except Exception as exc:
            print(f"Error {exc}")
            continue

        file_name = path.replace("/", "_") + ".json"
        with open(os.path.join(dest_root, file_name), "w") as handle:
            json.dump(data, handle, indent=2)
        print(f"Saved {path}")

        references = data.get("references", {})
        for ref in references.values():
            if not isinstance(ref, dict):
                continue
            ref_url = ref.get("url") or ""
            if isinstance(ref_url, str) and ref_url.startswith(f"/documentation/{module}"):
                queue.append(ref_url.strip("/"))


def main() -> None:
    if len(sys.argv) not in {2, 3}:
        print("Usage: python fetch_module_docs.py <module> [limit]")
        raise SystemExit(1)

    module = sys.argv[1]
    dest_root = os.path.join(os.path.dirname(__file__), module)
    limit = int(sys.argv[2]) if len(sys.argv) == 3 else None
    fetch_module(module, dest_root, limit)


if __name__ == "__main__":
    main()
