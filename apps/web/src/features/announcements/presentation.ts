export const APP_ANNOUNCEMENT_OPEN_EVENT = 'app:announcement:open'

export function openActiveAnnouncement() {
  window.dispatchEvent(new Event(APP_ANNOUNCEMENT_OPEN_EVENT))
}
