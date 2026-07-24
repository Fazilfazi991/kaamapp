export function photoInitials(name?: string | null) {
  const initials = (name ?? "")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase())
    .join("");
  return initials || "K";
}

export function isStoredPhotoPath(value?: string | null) {
  const photo = value?.trim() ?? "";
  return photo.length > 0 && !/^https?:\/\//i.test(photo);
}
