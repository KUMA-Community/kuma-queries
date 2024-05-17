# kuma-queries
**kuma_queries.sh v.1 (14.05.2024)**

Скрипт позволяет выполнять импорт/экспорт сохраненных запросов в формате JSON (в справке используется термин "конфигурация фильтра событий" - https://support.kaspersky.com/help/KUMA/3.0.3/ru-RU/228358.htm).  
В конфигурационном файле `product_list.cfg`, который можно использовать как аргумент скрипта, перечислены типы продуктов, запросы для которых необходимо импортировать. Если импорт запросов для определенного продукта не требуется необходимо заменить `true` на `false`. Без использования файла `product_list.cfg` выполняется импорт всех запросов.

## **Предварительные требования:**  
Работоспособность скрипта протестирована с версией KUMA 2.1 и 3.0.  
Для работы скрипта требуется наличие утилиты uuidgen:
```
apt-get install uuid-runtime
```  
После загрузки файла скрипта на сервер, сделать файл исполняемым:
```
chmod +x kuma_queries.sh  
```

## **Параметры запуска скрипта kuma_queries.sh:**
```
kuma_queries.sh [-h] [-import] [-export] <OPTIONS>

kuma_queries.sh -h                                     help  
kuma_queries.sh -import <FILENAME>                     import saved queries from JSON-file (e.g. saved_queries.json)  
kuma_queries.sh -import <FILENAME> <CONFIG FILE>       import saved queries from JSON-file for products specified in config file (e.g. saved_queries.json product_list.cfg)  
kuma_queries.sh -export                                export saved queries to the script directory  
kuma_queries.sh -export <DIRECTORY>                    export saved queries to the specific directory (e.g. /tmp)  
```
## **Примеры импорта:**
```
kuma_queries.sh -import saved_queries.json  
kuma_queries.sh -import saved_queries.json product_list.cfg  
```
## **Примеры экспорта:**
```
kuma_queries.sh -export  
kuma_queries.sh -export /tmp  
```

## **Дополнительная информация:**  
При экспорте нужно указывать только папку, например, /tmp. Файл сохраняется с именем kuma-saved-queries_$date.json  
Скрипт может работать некорректно при наличии нескольких кластеров Clickhouse.  

## **Поддерживаемые наименования запросов:**  
<Наименование продукта>; <Наименование фильтра>  

Например, 
```
Windows; <Наименование фильтра>  
Unix; <Наименование фильтра>  
KSC; <Наименование фильтра>  
KSMG; <Наименование фильтра>  
KWTS; <Наименование фильтра>  
KATA; <Наименование фильтра>  
KEDR; <Наименование фильтра>  
```
