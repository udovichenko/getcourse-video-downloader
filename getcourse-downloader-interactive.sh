#!/usr/bin/env bash
# Интерактивный скрипт для скачивания видео с GetCourse.ru
# Зависимости: bash, coreutils, curl, grep

set -eu
set +f
set -o pipefail

echo "=== Скачивание видео с GetCourse ==="
echo ""
echo "Как найти ссылку на плей-лист: https://github.com/mikhailnov/getcourse-video-downloader"
echo ""

read -r -p "Введите ссылку на плей-лист: " URL
URL="${URL//[[:space:]]/}"
if [ -z "$URL" ]; then
	echo "Ошибка: ссылка не может быть пустой."
	exit 1
fi

echo ""
current_dir="$(pwd)"
echo "Файл будет сохранён в текущую папку: $current_dir"
echo "Рекомендуемое расширение файла: .ts"
echo ""
read -r -p "Введите название файла (например: lesson-480-1.ts»): " filename
if [ -z "$filename" ]; then
	echo "Ошибка: имя файла не может быть пустым"
	exit 1
fi

result_file="${current_dir}/${filename}"
echo ""
echo "Файл будет сохранён как: $result_file"
echo ""

tmpdir="$(umask 077 && mktemp -d)"
export TMPDIR="$tmpdir"
trap 'rm -fr "$tmpdir"' EXIT

touch "$result_file"

main_playlist="$(mktemp)"
echo "Загружаю плей-лист..."
curl -L --output "$main_playlist" "$URL"

second_playlist="$(mktemp)"
if grep -qE '^https?:\/\/.*\.(ts|bin)' "$main_playlist" 2>/dev/null
then
	cp "$main_playlist" "$second_playlist"
else
	tail="$(tail -n1 "$main_playlist")"
	if ! [[ "$tail" =~ ^https?:// ]]; then
		echo ""
		echo "В содержимом заданной ссылки нет прямых ссылок на файлы *.bin (*.ts) (первый вариант),"
		echo "также последняя строка в ней не содержит ссылки на другой плей-лист (второй вариант)."
		echo "Либо указана неправильная ссылка, либо GetCourse изменил алгоритмы."
		echo "Если уверены, что дело в изменившихся алгоритмах GetCourse, опишите проблему здесь:"
		echo "https://github.com/mikhailnov/getcourse-video-downloader/issues (на русском)."
		exit 1
	fi
	echo "Загружаю дочерний плей-лист наилучшего качества..."
	curl -L --output "$second_playlist" "$tail"
fi

echo ""
echo "Начинаю скачивание фрагментов видео..."
c=0
while read -r line
do
	if ! [[ "$line" =~ ^http ]]; then continue; fi
	echo "  Фрагмент $((c+1))..."
	curl --retry 12 --retry-all-errors -Y 102400 -y 5 -L --output "${tmpdir}/$(printf '%05d' "$c").ts" "$line"
	c=$((++c))
done < "$second_playlist"

echo ""
echo "Собираю фрагменты в один файл..."
cat "$tmpdir"/*.ts > "$result_file"
echo ""
echo "✓ Скачивание завершено. Результат здесь:"
echo "  $result_file"

