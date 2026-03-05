# UI TODO — UI/UX Improvements

## Phase UI-1: Quick Fixes ✅
- [x] Remove "Logout" button from settings when user is guest
- [x] Fix EPUB cover extraction: 3 fallback methods (CoverImage → cover/jacket in Images → first large image)
- [x] Book cards: rounded corners (16px) with shadow/gradient
- [x] Added debug logging for cover extraction to help diagnose issues

## Phase UI-2: Localization (l10n) ✅
- [x] Add all UI strings to `app_en.arb` and `app_ru.arb` (60+ keys)
- [x] Replace all hardcoded English strings with `AppLocalizations` calls
- [x] Implement language selector in Settings (dialog with en/ru, saved to SharedPreferences)

## Phase UI-3: Library UX ✅
- [x] Move "Add book" button to FloatingActionButton (bottom right)
- [x] Add search button (top right) → opens search field to filter books by title/author
- [x] Add book detail screen (SliverAppBar cover, title, author, format, "Read" + "Delete" buttons)
- [x] Book card tap → book detail screen; "Read" button → reader

## Phase UI-4: Theme & Settings ✅
- [x] Implement theme toggle in Settings (Switch widget, saved to SharedPreferences)
- [x] Settings Sign In / Register → navigate to /login
- [ ] Add page transition animations (fade/slide for all routes)
- [ ] Add subtle animations: button hover, card press, list item appear

## Phase UI-5: Auth Improvements
- [x] When click on Sign In or Register buttons, open the login/register screen
- [ ] TODO: Add API calls for login/register with server validation
- [ ] TODO: Add input validation (min length, format, empty check)
- [ ] Consider: merge Login/Register into one screen or remove Register
- [ ] Add "Forgot password?" link (placeholder for future API)


## Phase UI-6: Final Fixes ✅
- [x] When click on language selector, theme selector - Navigation to the Library start screen is instantaneous. Similarly, when we click on Registration and Login, we also go to the Library screen. It shouldn't be like this, something is broken.
- [x] Shoals with a cover. The card can shrink or enlarge, and the cover area is either square or rectangular, and the cover "floats" inside, changing in size, and we sometimes see some part of the cover, then we don't see it after changing the size of the cards.
- [x] I don't like that book cards can grow infinitely in size as the application window increases. I want to set them to a certain maximum size. If it is reached, then with a further increase in the size of the window, the books simply "slide" into one line with the others, filling the empty space.
- [x] There are problems with cards now - the file type (EPUB/PDF) now sometimes seems to go beyond the boundaries of the card, for example, if the cards are small in size or if the book title is long.
- [x] I would assume a constant ratio of the area under the cover, BUT if the cover, for example, is more elongated down and up, then we make the lower and upper parts fit, and not on the left and right. That is, I want the ENTIRE cover to always fall into the area under the cover.
- [x] When switching to Sign in and Login in the settings, if you entered on behalf of the Guest, you still do not go to the login and registration screen. That is, as I understand it, the router is reassembled every time.

## Phase UI-6.1: Final Fixes (continued) ✅

- [x] На экране `Settings` есть пункты "Sign In" и "Register". Нам не нужен Register, потому что кнопка регистрации уже есть на экране `Login`. Удали пункт "Register" из настроек, пусть останется только "Sign In". Когда пользователь еще не авторизован - показывай только Sign in.
- [x] Названия книг на карточках `BookCard` могут быть очень длинными. В этом случае они занимают много места. Сделай так, чтобы название книги было в 1 строку, а если не помещается - ставилось ... (многоточие).
- [x] Информация о книге на карточке сейчас содержит только название, бейдж формата и обложку. Этого мало. Придумай, как можно красиво разместить больше информации на карточке (например, количество страниц, автора, размер файла, дату добавления и т.д.) так чтобы это не ломало верстку самой обложки. Либо, сделай экран `book details` (у нас уже есть заглушка) более информативным, покажи там всю инфу о книге. Если инфы будет много - убедись, что экран можно скроллить.
- [x] На данный момент мы можем добавить книгу в библиотеку, но не можем её редактировать. Названия книг часто содержат мусор, например `author_name_book_title_123.epub`. Нам нужно дать пользователю возможность редактировать название книги и автора. Сделай это. Опять же, подумай как это лучше сделать - на экране деталей книги, или прямо на карточке, или в диалоге.
- [x] Сейчас карточки с книгами на тёмной теме сливаются с фоном и отбрасывают просто черную тень. Добавь кастомную тень для карточек, чтобы они выглядели объемно и красиво. Например, эффект размытого свечения. Давай сделаем на темной теме, чтобы под ними была красивая тень в виде блюра. Цвет выбери из темы подходящий сам.

## Phase UI-6.2: Final Fixes

- [x] Есть такая строка кода: `book.format == 'epub' ? 'Read' : 'Open',`. Как видишь, здесь Read и Open - это хардкод. Нам нужно использовать наш l10n, чтобы в зависимости от языка приложения менять текст кнопки.
- [ ] Если изменить название книги или автора, то сразу на экране с деталями книги изменений НЕТ. Чтобы они отобразились, надо выйти из экрана деталей книги в основной экран - тогда на основном экране уже будут видны изменения, после чего и на экране деталей книги тоже они будут. Но хочется, чтобы мы сразу после изменения названия и автора ВИДЕЛИ изменение на экране с деталями о книге. 
- [ ] **НА БУДУЩЕЕ. НЕ ДЕЛАЙ ЭТО СЕЙЧАС!!!** Сейчас определение количества страниц для EPUB неправильное. Например, для книги, где в PDF оклоо 500-600 страниц, в EPUB пишет всего 47. Это связано с особенностями формата, конечно. Но хочется, чтобы как-то мы считали количество страниц в зависимости настроек нашего ридера - размер шрифта и всякое такое.
