/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Манукян Анжелика, 132 когорта
 * Дата:19.09.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
category_region AS(SELECT fi.id, f.total_area, f.rooms, f.balcony, f.floor, f.is_apartment, f.ceiling_height, f.parks_around3000,
						(CASE WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END) AS region,--разделение по регионам
   						(CASE WHEN a.days_exposition <= 30 THEN 'до месяца'
   						WHEN a.days_exposition BETWEEN 31 AND 90 THEN 'от одного до трёх месяцев'
   						WHEN a.days_exposition BETWEEN 91 AND 180 THEN 'от трёх месяцев до полугода'
   						WHEN a.days_exposition >= 181 THEN 'более полугода'
   						ELSE 'non category'
   						END) AS category, --разделение на категории по количеству дней активности
   						a.last_price::numeric / NULLIF(f.total_area,0) AS pice_area --стоимость 1 кв.м.
   				FROM filtered_id fi
   				LEFT JOIN real_estate.flats f ON fi.id = f.id 
   				LEFT JOIN real_estate.city c ON f.city_id =c.city_id 
   				LEFT JOIN real_estate.advertisement a ON fi.id = a.id
   				LEFT JOIN real_estate.TYPE t ON f.type_id = t.type_id
   				WHERE TYPE IN ('Санкт-Петербург', 'город') AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
   				)
SELECT cr.region, cr.category, 
		COUNT(cr.id) AS quantity, 
		ROUND(COUNT(cr.id) * 100.0 / SUM(COUNT(cr.id)) OVER (PARTITION BY cr.region), 2) AS share_exposition,
		ROUND(AVG(cr.pice_area::numeric), 2) AS avg_price,
		ROUND(AVG(cr.total_area::NUMERIC), 2) AS avg_area,
		ROUND(AVG(cr.ceiling_height::NUMERIC), 2) AS avg_ceiling_height,
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY cr.rooms) AS mediana_rooms, 
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY cr.balcony) AS mediana_balcony,
		PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY cr.floor) AS mediana_floor,
		ROUND(SUM(CASE WHEN cr.is_apartment = 1 THEN 1 END)*100.0 / COUNT(cr.id), 2) AS apartment,
		SUM(cr.parks_around3000) AS quantity_park
FROM category_region cr
GROUP BY cr.region, cr.category
ORDER BY cr.region, cr.category;


-- |region         |category                   |quantity|share_exposition|avg_price|avg_area|avg_ceiling_height|mediana_rooms|mediana_balcony|mediana_floor|apartment|quantity_park|
-- |---------------|---------------------------|--------|----------------|---------|--------|------------------|-------------|---------------|-------------|---------|-------------|
-- |ЛенОбл         |non category               |198     |7.00            |72925.89 |62.78   |2.80              |2            |1.0            |3            |0.51     |54.0         |
-- |ЛенОбл         |более полугода             |873     |30.87           |68215.11 |55.03   |2.72              |2            |1.0            |3            |0.11     |259.0        |
-- |ЛенОбл         |до месяца                  |340     |12.02           |71907.63 |48.75   |2.70              |2            |1.0            |4            |0.59     |113.0        |
-- |ЛенОбл         |от одного до трёх месяцев  |864     |30.55           |67423.80 |50.85   |2.71              |2            |1.0            |3            |0.12     |235.0        |
-- |ЛенОбл         |от трёх месяцев до полугода|553     |19.55           |69809.30 |51.83   |2.70              |2            |1.0            |3            |         |182.0        |
-- |Санкт-Петербург|non category               |653     |5.82            |136107.66|81.38   |2.90              |3            |1.0            |4            |1.07     |511.0        |
-- |Санкт-Петербург|более полугода             |3506    |31.26           |114981.07|65.76   |2.83              |2            |1.0            |5            |0.14     |2362.0       |
-- |Санкт-Петербург|до месяца                  |1794    |15.99           |108919.78|54.66   |2.76              |2            |1.0            |5            |0.22     |993.0        |
-- |Санкт-Петербург|от одного до трёх месяцев  |3020    |26.92           |110874.32|56.58   |2.77              |2            |1.0            |5            |0.10     |1748.0       |
-- |Санкт-Петербург|от трёх месяцев до полугода|2244    |20.01           |111973.67|60.55   |2.79              |2            |1.0            |5            |0.18     |1347.0       |


-- 1. Какие категории объявлений являются самыми распространёнными в Санкт-Петербурге и городах Ленинградской области?
 -- Анализ показал одинаково большое количество в категории «более полугода»: Санкт-Петербург 3 506 объявлений, Ленинградская область 873. 
 -- На след месте категория «от одного до трёх месяцев».: Санкт-Петербург 3 020 объявлений, Ленинградская область 864. Для Ленинградской области не большая разница в количестве между категориями.

-- 2. Какие характеристики недвижимости, включая площадь недвижимости, среднюю стоимость квадратного метра, количество комнат и балконов и другие параметры, влияют на время активности объявлений? 
-- Как эти зависимости варьируют между регионами?
-- Данные были отфильтрованы по перцентилям. Это важно, особенно при анализе средней площади и средней цены — без фильтрации такие метрики искажаются
-- В Ленинградской области с меньшей площадью продаются значительно быстрее, при том что стоимость квадратного метра не самая низкая на рынке по категориям. 
-- Можно сделать вывод, что приоритет в общей стоимости объекта, а не за метр. Этаж более предпочитаемый – 4. Наличие парка рядом не влияет на покупку квартир.
-- В Санкт Петербурге значительно больше продаются квартиры не только. с минимальной площадью, но и минимальной стоимостью. Это объясняется высоким спросом на доступное жилье со стороны покупателя. Основная часть объявлений – 5 этаж. Наличие парка – ключевой показатель для городского покупателя и большее количество объявлений содержит информацию о парках.
-- По количеству комнат можно сказать, что рынок сконцентрирован вокруг двухкомнатных квартир с одним балконом. 

-- 3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
	-- Анализ показывает, что средняя стоимость квадратного метра в Санкт-Петербурге превышает показатели Ленинградской области. 
	-- При этом в Санкт-Петербурге также фиксируется большая средняя площадь квартир.

    
-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ), 
season_first AS(SELECT EXTRACT(MONTH FROM DATE(a.first_day_exposition)) AS public_first,
					(CASE WHEN EXTRACT(MONTH FROM DATE(a.first_day_exposition)) IN(3,4,5) THEN 'весна'
						  WHEN EXTRACT(MONTH FROM DATE(a.first_day_exposition)) IN(6,7,8) THEN 'лето'
						  WHEN EXTRACT(MONTH FROM DATE(a.first_day_exposition)) IN(9,10,11) THEN 'осень'
						  ELSE 'зима'
						  END) AS season_public,
						  COUNT(fi.id) AS public_exposition,
						  AVG(a.last_price::numeric / NULLIF(f.total_area,0)) AS avg_price_first,
						  AVG(NULLIF(f.total_area,0)) AS avg_area_first 
				FROM filtered_id fi
				LEFT JOIN real_estate.advertisement a ON fi.id = a.id
				LEFT JOIN real_estate.flats f ON fi.id = f.id 
				LEFT JOIN real_estate.TYPE t ON f.type_id = t.type_id
				WHERE a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' AND TYPE IN ('Санкт-Петербург', 'город') 
				GROUP BY public_first, season_public
				),
season_over AS(SELECT EXTRACT(MONTH FROM DATE(a.first_day_exposition + INTERVAL '1 DAY' * a.days_exposition)) AS public_over,
						(CASE WHEN EXTRACT(MONTH FROM DATE(a.first_day_exposition + INTERVAL '1 DAY' * a.days_exposition)) IN(3,4,5) THEN 'весна'
						  WHEN EXTRACT(MONTH FROM DATE(a.first_day_exposition + INTERVAL '1 DAY' * a.days_exposition)) IN(6,7,8) THEN 'лето'
						  WHEN EXTRACT(MONTH FROM DATE(a.first_day_exposition + INTERVAL '1 DAY' * a.days_exposition)) IN(9,10,11) THEN 'осень'
						  ELSE 'зима'
						  END) AS season_finish,
						  COUNT(fi.id) AS over_exposition,
						  AVG(a.last_price::numeric / NULLIF(f.total_area,0)) AS avg_price_over,
						  AVG(NULLIF(f.total_area,0)) AS avg_area_over 
				FROM filtered_id fi
				LEFT JOIN real_estate.advertisement a ON fi.id = a.id
				LEFT JOIN real_estate.flats f ON fi.id = f.id 
				LEFT JOIN real_estate.TYPE t ON f.type_id = t.type_id
				WHERE a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' 
						AND TYPE IN ('Санкт-Петербург', 'город') 
						AND a.days_exposition IS NOT NULL
				GROUP BY public_over, season_finish
				)
SELECT sf.public_first, 
	   sf.season_public,
	   'публикация' AS type_exposition,
	   sf.public_exposition,
	   MAX(sf.public_exposition) OVER(PARTITION BY sf.season_public),
	   MIN(sf.public_exposition) OVER(PARTITION BY sf.season_public),
	   ROUND(sf.avg_price_first::numeric, 2) AS avg_first_price, 
	   ROUND(sf.avg_area_first::numeric, 2) AS avg_first_area,
	   so.public_over, 
	   so.season_finish,
	   'снятие' AS type_exposition,
	   so.over_exposition,
	   MAX(so.over_exposition) OVER(PARTITION BY so.season_finish),
	   MIN(so.over_exposition) OVER(PARTITION BY so.season_finish),
	   ROUND(so.avg_price_over::numeric, 2) AS avg_over_price, 
	   ROUND(so.avg_area_over::NUMERIC, 2) AS avg_over_area 				
FROM season_first sf
FULL JOIN season_over so ON sf.public_first = so.public_over
ORDER BY sf.public_first, 
	   sf.season_public;

-- |public_first|season_public|type_exposition|public_exposition|max |min |avg_first_price|avg_first_area|public_over|season_finish|type_exposition|over_exposition|max |min |avg_over_price|avg_over_area|
-- |------------|-------------|---------------|-----------------|----|----|---------------|--------------|-----------|-------------|---------------|---------------|----|----|--------------|-------------|
-- |1           |зима         |публикация     |735              |1369|735 |106106.24      |59.16         |1          |зима         |снятие         |1225           |1225|1048|104947.31     |57.53        |
-- |2           |зима         |публикация     |1369             |1369|735 |103058.51      |60.10         |2          |зима         |снятие         |1048           |1225|1048|103883.72     |61.12        |
-- |3           |весна        |публикация     |1119             |1119|891 |102429.95      |60.00         |3          |весна        |снятие         |1071           |1071|729 |106832.40     |60.37        |
-- |4           |весна        |публикация     |1021             |1119|891 |102632.41      |60.60         |4          |весна        |снятие         |1031           |1071|729 |102444.24     |59.22        |
-- |5           |весна        |публикация     |891              |1119|891 |102465.12      |59.19         |5          |весна        |снятие         |729            |1071|729 |99724.07      |57.78        |
-- |6           |лето         |публикация     |1224             |1224|1149|104802.15      |58.37         |6          |лето         |снятие         |771            |1137|771 |101863.69     |59.82        |
-- |7           |лето         |публикация     |1149             |1224|1149|104488.96      |60.42         |7          |лето         |снятие         |1108           |1137|771 |102290.72     |58.54        |
-- |8           |лето         |публикация     |1166             |1224|1149|107034.70      |58.99         |8          |лето         |снятие         |1137           |1137|771 |100036.51     |56.83        |
-- |9           |осень        |публикация     |1341             |1569|1341|107563.12      |61.04         |9          |осень        |снятие         |1238           |1360|1238|104070.07     |57.49        |
-- |10          |осень        |публикация     |1437             |1569|1341|104065.11      |59.43         |10         |осень        |снятие         |1360           |1360|1238|104317.33     |58.86        |
-- |11          |осень        |публикация     |1569             |1569|1341|105048.80      |59.58         |11         |осень        |снятие         |1301           |1360|1238|103791.36     |56.71        |
-- |12          |зима         |публикация     |1024             |1369|735 |104775.39      |58.84         |12         |зима         |снятие         |1175           |1225|1048|105504.52     |59.26        |

-- 1. В какие месяцы наблюдается наибольшая активность в публикации объявлений о продаже недвижимости? А в какие — по снятию? Это показывает динамику активности покупателей.
-- Наибольшая активность в публикации объявлений приходится на осенние месяцы, также, как и по снятию.
-- 2. Совпадают ли периоды активной публикации объявлений и периоды, когда происходит повышенная продажа недвижимости (по месяцам снятия объявлений)?
-- В ноябре наблюдается максимум в публикации объявлений, а в снятии объявлений октябрь. Можно сказать, период совпадает. 
-- 3. Как сезонные колебания влияют на среднюю стоимость квадратного метра и среднюю площадь квартир? Что можно сказать о зависимости этих параметров от месяца?
-- В связи с большим выбором на рынке недвижимости в осеннее время наблюдаются высокие цены в публикации и в снятии объявлений. 
-- Если сравнить схожие площади квартир по стоимости в разные время года, то наблюдается и высокая стоимость именно в осеннее время года.

-- Общие выводы и рекомендации
-- Наиболее быстрая продажа - 1-2 комнатные квартиры, с небольшой площадью. Анализ показал: выставлять объект осенью – стратегически верно.  
-- Летом минимальное количество объявлений снимается. Это связано, скорей всего, с отпусками.   
 

