### 2.0.5

- fix: crucial bug where people couldn't use the config
- feat: make the musicpopup match the theme more by making the dim on the art in the background have the base theme color instead of black
- fix: make external kitty/fatfetch/cava configs not reinstall itself on update, and make location not re-evaluate itself on updates
- feat(i18n): add Armenian translation (#191)

### 2.0.4

- replace hardcoded delete buttons with a reusable
- Fix the calendar popup nodes having wrong scaling behavior breaking the 3d illusion
- feat: add a new reusable icon button instance for "delete button" implementation
- fix: prevent color theme reloads when the theme didn't actually change
- feat: add sub-nested tabs in the displaytab and split the widgets tab in the displaytab
- feat: make the launcher change its size based on the amount of elements and move the input to the bottom when attached to the bottom side of the screen
- feat: make the clipboard change its size based on the amount of elements and move the input to the bottom when attached to the bottom side of the screen
- docs: add a PR template
- Italian Translation fixes (#186)
- feat: make the Sddm theme have a better typing animation
- fix: remove sddm on-screen keyboard for some users
- fix: make config.sh not merge it on update

### 2.0.3

- fix: system options in the systempanel not being adapted to different init systems and different compositors
- feat: allow the launcher and the clipboard to close by clicking outside of their area- fix: make the draggable for changing sfx volume in the generaltab change the sound volume immidiatly on drag to allow the user to listen to how loud the sfx is directly
- Remove update notifications in the abouttab for nixos as redundant and disable updater singleton for nixos
- style: improve the appearing and disappearing animation for a volume/brightness osd when not attached to a bar)
- feat(notifications): add toggle for empty center graphic
- fix: make i18n fallback to english if a language misses a key, and only then fallback to a key
- feat(i18n): Add Italian localization
