import asyncio
import json
import os
from playwright.async_api import async_playwright

async def main():
    print("Запуск браузера...")
    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page()
        
        print("Переход на страницу...")
        await page.goto("https://quotes.toscrape.com/scroll", wait_until="domcontentloaded")
        
        # Ждём появления первого элемента цитаты (значит, JS отработал)
        await page.wait_for_selector(".quote")
        
        # Прокручиваем страницу вниз, чтобы подгрузились дополнительные цитаты
        await page.evaluate("""async () => {
            await new Promise(resolve => {
                let totalHeight = 0;
                const distance = 200;
                const timer = setInterval(() => {
                    window.scrollBy(0, distance);
                    totalHeight += distance;
                    if (totalHeight >= 600) {
                        clearInterval(timer);
                        resolve();
                    }
                }, 100);
            });
        }""")
        
        # Даём секунду на рендеринг новых элементов после скролла
        await asyncio.sleep(1)

        print("Извлечение данных...")
        quotes = await page.evaluate("""() => {
            const elements = document.querySelectorAll('.quote');
            return Array.from(elements).map(el => ({
                text: el.querySelector('.text')?.innerText || '',
                author: el.querySelector('.author')?.innerText || ''
            }));
        }""")

        await browser.close()

        # Гарантируем существование папки out
        os.makedirs("out", exist_ok=True)

        with open("out/result.json", "w", encoding="utf-8") as f:
            json.dump(quotes, f, indent=2, ensure_ascii=False)
            
        print(f"Успешно сохранено {len(quotes)} цитат в out/result.json")

if __name__ == "__main__":
    asyncio.run(main())
    