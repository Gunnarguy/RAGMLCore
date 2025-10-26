import os
import re
import shutil

ROOT = os.path.dirname(__file__)
PATTERN = re.compile(r"essentials/([A-Za-z0-9_\-\.\(\):]+\.json)")


def copy_file(raw_dir: str, dest_dir: str, target_name: str) -> tuple[str | None, str | None]:
    src_exact = os.path.join(raw_dir, target_name)
    if os.path.exists(src_exact):
        dest_path = os.path.join(dest_dir, target_name)
        shutil.copy2(src_exact, dest_path)
        return target_name, None

    base = target_name[:-5]
    try:
        candidates = [name for name in os.listdir(raw_dir) if name.startswith(base)]
    except FileNotFoundError:
        return None, target_name

    if candidates:
        candidates.sort(key=len)
        chosen = candidates[0]
        src_path = os.path.join(raw_dir, chosen)
        dest_path = os.path.join(dest_dir, chosen)
        shutil.copy2(src_path, dest_path)
        return chosen, None

    return None, target_name


def process_directory(directory: str) -> tuple[int, list[str]]:
    readme_path = os.path.join(directory, "README.md")
    if not os.path.exists(readme_path):
        return 0, []

    with open(readme_path, "r", encoding="utf-8") as handle:
        content = handle.read()

    filenames = set(PATTERN.findall(content))
    if not filenames:
        return 0, []

    raw_dir = os.path.join(directory, "raw")
    dest_dir = os.path.join(directory, "essentials")
    os.makedirs(dest_dir, exist_ok=True)

    copied = 0
    missing: list[str] = []

    for name in sorted(filenames):
        copied_name, missing_name = copy_file(raw_dir, dest_dir, name)
        if copied_name:
            copied += 1
        elif missing_name:
            missing.append(missing_name)

    return copied, missing


def main() -> None:
    for entry in sorted(os.listdir(ROOT)):
        directory = os.path.join(ROOT, entry)
        if not os.path.isdir(directory):
            continue
        if entry.startswith('.'):
            continue

        copied, missing = process_directory(directory)
        if copied == 0 and not missing:
            continue

        print(f"{entry}: copied {copied} files")
        if missing:
            preview = ', '.join(missing[:10])
            if len(missing) > 10:
                preview += ', ...'
            print(f"  Missing {len(missing)} file(s): {preview}")


if __name__ == "__main__":
    main()
