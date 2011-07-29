-*-nuweb-mode-*-

2010 28 июля
начинаю писать концепт даммаку



1)стараюсь делать по KISS
2)делаю тяпляп, лишь бы работало
3)я делаю Touhou, а не универсальный двиг


==========================================================

Игровые константы.


@o const.h @{
#ifndef _CONST_H_
#define _CONST_H_

@<const.h game field width and height@>
@<const.h game field coodinate@>

#endif
@}


Размер игрового поля, где происходит действие игры:
@d const.h game field width and height @{
#define GAME_FIELD_W 380
#define GAME_FIELD_H 580
@}
Использовать в алгоритмах. Начало в точке (0, 0).


Левый верхний угол игрового поля, где происходит действие игры:
@d const.h game field coodinate @{
#define GAME_FIELD_X 10
#define GAME_FIELD_Y 10
@}
Лучше помещать эти константы в функции вырисовки, а не в алгоритмы.

Константа для линии на которой лежат бонусы:
@d const.h game field coodinate @{
#define GAME_BONUS_LINE 180
@}
Отсчитывается от 0, а не от GAME_FIELD_Y.

===========================================================

Набор функция для работы с окном(создание, рисование...).



Структура файла функций зависимых от ОС:
@o os_specific.c @{
#include <SDL.h>
#include <SDL_image.h>

#include <GL/gl.h>
//#include <GL/glu.h>

#include <stdlib.h>
#include <math.h>

#include "os_specific.h"

static SDL_Surface *surface;

@<os_specific structs@>
@<os_specific private prototypes@>
@<os_specific functions@>
@}

@o os_specific.h @{
@<os_specific public prototypes@>
@}


Эту функцию вызывают один раз, когда программа запускается(в начале функции main):
@d os_specific functions @{
void window_init(void) {
	if(SDL_Init(SDL_INIT_VIDEO|SDL_INIT_TIMER) != 0) {
		fprintf(stderr, "\nUnable to initialize SDL:  %s\n",
				SDL_GetError());
		exit(1);
	}

	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 5);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
}
@}

@d os_specific public prototypes @{
void window_init(void);
@}




Нам нужна функция, которая создаёт окно(window_create). Её также нужно вызывать после изменения
характеристик окна.
Изменение характеристик приводит к изменению настроек OGL, следовательно OGL стоит
настраивать в этой функции.




@d os_specific functions @{
static int w = 800, h = 600, fullscreen;
static int game_w = 800, game_h = 600;
static Uint32 flags = SDL_OPENGL;

void window_create(void) {

	flags = fullscreen ? flags | SDL_FULLSCREEN : flags & ~SDL_FULLSCREEN;

	surface = SDL_SetVideoMode(w, h, 16, flags);
	if(surface == NULL) {
		fprintf(stderr, "Unable to set 800x600 video: %s\n", SDL_GetError());
		exit(1);
	}

	window_set_2d_config();

	return;
}
@}
w, h - размеры окна
game_w, game_h - размеры окна в игре, они будут растягиваться под w, h

@d os_specific public prototypes @{
void window_create(void);
@}


Настройки OGL для вывода 2D графики:
@d os_specific functions @{
void window_set_2d_config(void) {
	glClearColor(0, 0, 0, 0);
	//glClear(GL_COLOR_BUFFER_BIT);

	glEnable(GL_TEXTURE_2D);

	@<window_set_2d_config OGL blend@>

	glViewport(0, 0, w, h);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	glOrtho(0, game_w, game_h, 0, 0, 1);

	glDisable(GL_DEPTH_TEST);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}
@}

Нам нужна поддержка прозрачности для вывода спрайтов с alpha каналом:
@d window_set_2d_config OGL blend @{
glEnable(GL_BLEND);
glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
@}

@d os_specific public prototypes @{
void window_set_2d_config(void);
@}



Функция изменения размера окна:
@d os_specific functions @{
void window_set_size(int w_, int h_) {
	w = w_;
	h = h_;

	window_create();
}
@}
Как видно window_create она запускает сама. Может кому-то и не нравятся мелькающие окна, а мне
пофиг.

@d os_specific public prototypes @{
void window_set_size(int w_, int h_);
@}



Очень простые функции для работы с fullscreen:
@d os_specific functions @{
void window_set_fullscreen(int flag) {
	fullscreen = flag;

	window_create();
}

int window_is_fullscreen(void) {
	return fullscreen;
}
@}

@d os_specific public prototypes @{
void window_set_fullscreen(int flag);
int window_is_fullscreen(void);
@}



Эту фунцию вызывают когда уже все нарисовано в буфере:
@d os_specific functions @{
void window_update(void) {
	SDL_GL_SwapBuffers();
}
@}

@d os_specific public prototypes @{
void window_update(void);
@}




Перейдём к функциям по работе с изображениями.

image_load будет кроме возвращения дескриптора ещё сохранять имя файла для защиты от
двойной загрузки файла(FIXME:надо реализовать).

Так как нам придётся проверять все рисунки, то мы будем их хранить в массиве.
Для начала, почему массив? Этот массив похож на стек. Список рисунков всё равно не
имеет дыр, поэтому будем использовать этот достаточно простой вариант.
id который возвращает image_load и есть номер элемента в массиве.

Опишем структуру в которой будет храниться список открытых изображений:
@d os_specific structs @{
#define IMAGE_LIST_LEN 1024
#define IMG_FILE_NAME_SIZE 30

typedef struct {
	char filename[IMG_FILE_NAME_SIZE];
	int w, h;
	unsigned int tex_id;
} ImageList;

static ImageList image_list[IMAGE_LIST_LEN];
static int image_list_pos;
@}
Это стек, image_list_pos его вершина.
IMG_FILE_NAME_SIZE длинна массива под имя файла включая и путь к файлу.
IMAGE_LIST_LEN количество изображений или иными словами размер стека.

filename - имя файла с картинкой
w, h - размеры картинки
tex_id - дескриптор текстуры в opengl



Функция загрузки изображения image_load:
@d os_specific functions @{
int image_load(char *filename) {
	if(image_list_pos == IMAGE_LIST_LEN) {
		fprintf(stderr, "\nImage list full\n");
		exit(1);
	}

	strncpy(image_list[image_list_pos].filename, filename,
			sizeof(image_list[image_list_pos].filename));

	{
		int bytes_per_pixel;
		int texture_format;

		ImageList *image = &image_list[image_list_pos];

		SDL_Surface *img = load_from_file(filename);

		@<os_specific image file size check@>
		@<os_specific set bytes_per_pixel and texture_format@>

		image->w = img->w;
		image->h = img->h;

		glGenTextures(1, &image->tex_id);

		glBindTexture(GL_TEXTURE_2D, image->tex_id);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		glTexImage2D(GL_TEXTURE_2D, 0, bytes_per_pixel, img->w, img->h, 0,
			texture_format, GL_UNSIGNED_BYTE, img->pixels);

		SDL_FreeSurface(img);
	}

	return image_list_pos++;
}
@}
Как видно есть контроль переполнения буфера, где хранится имя файла.
То есть в структуре-стеке всегда валидное имя.
Используется вспомогательная функция load_from_file, она загружает картинку по заданому пути.
Функция image_load возвращает позицию в стеке, она служит дескриптором изображения.

@d os_specific public prototypes @{
int image_load(char *filename);
@}


Размер должен быть кратен 2:
@d os_specific image file size check @{
if((img->w & (img->w - 1)) != 0 ||
	(img->h & (img->h - 1)) != 0) {
	fprintf(stderr, "\nImage size isn't power of 2: %s\n", filename);
	exit(1);
}
@}

Получить количество байтов на пиксел и формат изображения:
@d os_specific set bytes_per_pixel and texture_format @{
bytes_per_pixel = img->format->BytesPerPixel;

switch(bytes_per_pixel) {
	case 4:
		if(img->format->Rmask == 0x000000ff)
			texture_format = GL_RGBA;
		else
			texture_format = GL_BGRA;
		break;
	case 3:
		if(img->format->Rmask == 0x000000ff)
			texture_format = GL_RGB;
		else
			texture_format = GL_BGR;
		break;
	default:
		fprintf(stderr, "\nIncorect color type: %s\n", filename);
		exit(1);
}
@}
Допустимо только 4 или 3 байта на пиксел.



Теперь о вспомогательной функции подробнее:
@d os_specific functions @{
static SDL_Surface *load_from_file(char *filename) {
	SDL_Surface *img;
	char dirname[] = "images/";
	char buf[IMG_FILE_NAME_SIZE + sizeof(dirname) + 1];

	strcpy(buf, dirname);
	strcat(buf, filename);

	img = IMG_Load(buf);
	if(img == 0) {
		fprintf(stderr, "IMG_Load: %s\n", IMG_GetError());
		exit(1);
	}
}
@}
У функция подсчитывает количество символов в имени директории и создаёт подходящий массив.
Она не проверяет есть ли '.' в пути к файлу, это потенциальная уязвимость, но пока это меня
не беспокоит :3

@d os_specific private prototypes @{
static SDL_Surface *load_from_file(char *filename);
@}




Функция вывода изображения с левого-верхнего края:
@d os_specific functions @{
void image_draw_corner(int id, int x, int y, float rot, float scale) {
	ImageList *img = &image_list[id];

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	glBegin(GL_QUADS);
		glTexCoord2i(0, 0);
		glVertex2i(0, 0);

		glTexCoord2i(1, 0);
		glVertex2i(img->w, 0);

		glTexCoord2i(1, 1);
		glVertex2i(img->w, img->h);


		glTexCoord2i(0, 1);
		glVertex2i(0, img->h);
	glEnd();
}
@}

@d os_specific public prototypes @{
void image_draw_corner(int id, int x, int y, float rot, float scale);
@}



Функция вывода изображения с центра:
@d os_specific functions @{
void image_draw_center(int id, int x, int y, float rot, float scale) {
	ImageList *img = &image_list[id];

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);
	glRotatef(rot, 0, 0, 1);
	glScalef(scale, scale, 0);

	glBegin(GL_QUADS);
		glTexCoord2i(0, 0);
		glVertex2i(-img->w/2, -img->h/2);

		glTexCoord2i(1, 0);
		glVertex2i(img->w/2, -img->h/2);

		glTexCoord2i(1, 1);
		glVertex2i(img->w/2, img->h/2);

		glTexCoord2i(0, 1);
		glVertex2i(-img->w/2, img->h/2);
	glEnd();
}
@}

@d os_specific public prototypes @{
void image_draw_center(int id, int x, int y, float rot, float scale);
@}


Функция возврата процессорного времени OS:
@d os_specific public prototypes @{
void get_processor_time(void);
@}

@d os_specific functions @{
void get_processor_time(void) {
	SDL_Delay(0);
}
@}


===============================================================

Переходим к реализации событий.

Итак нажатие клавиш. Тут можно выделить два подхода:

1) Завести функцию get_scan_keydown() она будет говорить какая кнопка была нажата последней и
get_scan_keyup() -- какая была отпущена последней.
2) Завести функцию вида is_keydown(int key) она говорит была ли нажата кнопка key

Первый вариант платформозависим, но проще в реализации. Второй вариант тоже зависим, но не так
сильно.

Улучшим второй вариант, вместо кода кнопки, будем передавать событие. Например вместо Up_Key будем передавать
"двигаться вверх". Функция в ответ возвращает 0 или 1, не была нажата или была.

@o event.h @{

@<keys' events for is_keydown@>
@<is_keydown function prototype@>

@}

Придумаем события:

@d keys' events for is_keydown @{

enum {
	key_fire, key_shadow_character, key_card,
	key_move_left, key_move_right, key_move_up, key_move_down,
	key_menu_up, key_menu_down, key_menu_select, key_escape
};

@}

Интересно, есть устройства где для перемещению по меню используются другие кнопки? Пусть будут.

@d is_keydown function prototype @{
int is_keydown(int key_type);
@}

Реализация is_keydown:

@o event.c @{
#include <SDL.h>

#include <stdlib.h>

#include "event.h"

@<Key flags@>

int is_keydown(int key_type) {
	SDL_Event event;

	@<Get event@>
	@<Return key state@>

	return 0;
}
@}

Эти флаги устанавливаются в 1, если кнопка нажата и в 0, если нет:
@d Key flags @{
static int fire, shadow_character, card, move_left, move_right, move_up, move_down, escape;
@}

Здесь мы устанавливаем и сбрасываем флаги:
@d Get event @{
while(SDL_PollEvent(&event)) {
	int key = event.type == SDL_KEYDOWN;

	switch(event.key.keysym.sym) {
		case SDLK_z:
			fire = key;
			break;
		case SDLK_x:
			card = key;
			break;
		case SDLK_LSHIFT:
			shadow_character = key;
			break;
		case SDLK_LEFT:
			move_left = key;
			break;
		case SDLK_RIGHT:
			move_right = key;
			break;
		case SDLK_UP:
			move_up = key;
			break;
		case SDLK_DOWN:
			move_down = key;
			break;
		case SDLK_ESCAPE:
			escape = key;
			break;
	}
}
@}

Тут возвращаем ответ на запрос: установлен флаг у кнопки или нет.

@d Return key state @{
switch(key_type) {
	case key_fire:
		return fire;
	case key_card:
		return card;
	case key_shadow_character:
		return shadow_character;
	case key_move_left:
		return move_left;
	case key_move_right:
		return move_right;
	case key_move_up:
	case key_menu_up:
		return move_up;
	case key_move_down:
	case key_menu_down:
		return move_down;
	case key_escape:
		return escape;
	default:
		fprintf(stderr, "\nUnknown key\n");
		exit(1);
}
@}


======================================================

Простой набор функций контроля пересечения прямоугольников:

@o collision.h @{
typedef struct {
	int l, r, t, b;
} Rect;

int is_collide(const Rect *a, const Rect *b);
@}

Реализация:

@o collision.c @{
#include <math.h>

#include "collision.h"

int is_collide(const Rect *a, const Rect *b) {
	int vert = 0, horz = 0;

	if(a->l < b->r && a->l > b->l)
		vert = 1;
	else if(a->r < b->r && a->r > b->l)
		vert = 1;

	if(a->t < b->b && a->t > b->t)
		horz = 1;
	else if(a->b < b->b && a->b > b->t)
		horz = 1;

	if(vert && horz)
		return 1;

	return 0;
}
@}

Пересечение окружностей:
@o collision.h @{
int is_rad_collide(int x1, int y1, int r1, int x2, int y2, int r2);
@}

@o collision.c @{
int is_rad_collide(int x1, int y1, int r1, int x2, int y2, int r2) {
	int dx = x2-x1;
	int dy = y2-y1;
	double dist = sqrt(dx*dx + dy*dy);

	if(dist < r1 + r2)
		return 1;

	return 0;
}
@}

===========================================================

Персонажи.

Теперь стоит подумать о игровых персонажах.
Они должны иметь возможность свободно перемещаться по игровому полю и исчезать когда им захочется.

-Должны ли пули и снаряды хранится с игровыми персонажами в одном списке?
Пули не возвращают дескрипторы(их слишком много). Этим они отличаются от персонажей.

Пули будут иметь специальную функцию, которая принимает прямоугольник у персонажа и сообщает было пересечение
или нет.
Возможен и обратный подход, когда персонаж имеет функцию, а пуля прямоугольник пересечения, но в таком
случае мы не сможем отображать снизу области поражения вражеских персонажей.
Функция перемещения, её вызов двигает снаряд на итерацию.


@o characters.h @{
@<Character public structs@>
@<Character public prototypes@>
@}



Опишем структуру персонажа:
@d Character public structs @{
#define CHARACTER_LIST_LEN 2040

typedef struct {
	int hp;
	int x;
	int y;
	int is_sleep;
	int character_type;
	int time_point_for_movement_to_x;
	int time_point_for_movement_to_y;
	@<Character struct param@>
} CharacterList;

extern CharacterList characters[CHARACTER_LIST_LEN];
extern int characters_pos;
@}

CHARACTER_LIST_LEN максимальный размер стека с игровыми персонажами.
characters_pos вершина стека

О структуре:
  hp - количество жизней персонажа
  x, y - координаты, когда он не спит
  is_sleep - флаг, спит персонаж или действует на поле игры. Если персонаж умер,
  		   	 то флаг устанавливается(true).
  character_type - тип персонажа, основной параметр для диспетчеризации
  time_point_for_movement_to_x - может или нет персонаж переместиться по координате x,
  							   	 если этот параметр равен 0, то может. Этот параметр
								 уменьшается функцией characters_update_all_time_points,
								 и увеличивается функцией перемещения по координате x
  time_point_for_movement_to_y - аналогично time_point_for_movement_to_x

@o characters.c @{
#include <stdio.h>
#include <stdlib.h>

#include "characters.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"
#include "bullets.h"
#include "timers.h"

CharacterList characters[CHARACTER_LIST_LEN];
int characters_pos;

@<Character private structs@>
@<Character private prototypes@>
@<Character functions@>
@}


Перейдем к реализации функций.


Функции создания персонажей.

Типы персонажей:
@d Character public structs @{
enum {
	character_reimu, character_marisa, @<Character types@>
};
@}

Рейму:
@d Character functions @{
void character_reimu_create(int cd) {
	CharacterList *character = &characters[cd];

	character->hp = 100;
	character->is_sleep = 1;
	character->character_type = character_reimu;
	character->time_point_for_movement_to_x = 0;
	character->time_point_for_movement_to_y = 0;
	character->step_of_movement = 0;

	character->x = player_x;
	character->y = player_y;

	character->radius = 10;
}
@}
player_coord_x, player_coord_y - глобальные координаты игрока.
radius - радиус хитбокса.

@d Character public prototypes @{@-
void character_reimu_create(int cd);
@}

Мариса:
@d Character functions @{
void character_marisa_create(int cd) {
	CharacterList *character = &characters[cd];

	character->hp = 100;
	character->is_sleep = 1;
	character->character_type = character_marisa;
	character->time_point_for_movement_to_x = 0;
	character->time_point_for_movement_to_y = 0;
	character->step_of_movement = 0;

	character->x = player_x;
	character->y = player_y;

	character->radius = 10;
}
@}

@d Character public prototypes @{@-
void character_marisa_create(int cd);
@}



Функции перемещения и восстановления очков перемещения.

Опишем вначале функцию перемещения:
@d Character functions @{
@<Different characters set weak time_point functions@>
@<character_set_weak_time_point functions@>

static void character_move_to(int cd, int move_to) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x == 0) {
		if(move_to == character_move_to_left) {
			character_set_weak_time_point_x(cd);
			character->x--;
		}
		else if(move_to == character_move_to_right) {
			character_set_weak_time_point_x(cd);
			character->x++;
		}
	}

	if(character->time_point_for_movement_to_y == 0) {
		if(move_to == character_move_to_up) {
			character_set_weak_time_point_y(cd);
			character->y--;
		}
		else if(move_to == character_move_to_down) {
			character_set_weak_time_point_y(cd);
			character->y++;
		}
	}
}
@}

В этой функции используются функции character_set_weak_time_point_x и
character_set_weak_time_point_y. Они определяют тип персонажа cd и
вызывают специализированию функцию для каждого типа персонажа. Она устанавливает
значение для time_point_for_movement_to_x и time_point_for_movement_to_y
после того как было сделано перемещение.

Как видно, ход по x или y возможен только если соответствующий time_point равен нулю.

Направления в которые может перемещаться персонаж:
@d Character private structs @{
enum {
	character_move_to_left, character_move_to_right, character_move_to_up, character_move_to_down
};
@}

@d Character private prototypes @{
static void character_move_to(int cd, int move_to);
@}



Опишем character_set_weak_time_point_x и character_set_weak_time_point_y:
@d character_set_weak_time_point functions @{
static void character_set_weak_time_point_x(int cd) {
	switch(characters[cd].character_type) {
		case character_reimu:
			character_reimu_set_weak_time_point_x(cd);
			break;
		case character_marisa:
			character_marisa_set_weak_time_point_x(cd);
			break;
		@<character_set_weak_time_point_x other characters@>
		default:
			fprintf(stderr, "\nUnknown character\n");
			exit(1);
	}
}

static void character_set_weak_time_point_y(int cd) {
	switch(characters[cd].character_type) {
		case character_reimu:
			character_reimu_set_weak_time_point_y(cd);
			break;
		case character_marisa:
			character_marisa_set_weak_time_point_y(cd);
			break;
		@<character_set_weak_time_point_y other characters@>
		default:
			fprintf(stderr, "\nUnknown character\n");
			exit(1);
	}
}

@}

Конкретные реализации функций обновления time_point:

@d Different characters set weak time_point functions @{
static void character_reimu_set_weak_time_point_x(int cd) {
	characters[cd].time_point_for_movement_to_x = 5;
}

static void character_reimu_set_weak_time_point_y(int cd) {
	characters[cd].time_point_for_movement_to_y = 5;
}

static void character_marisa_set_weak_time_point_x(int cd) {
	characters[cd].time_point_for_movement_to_x = 10;
}

static void character_marisa_set_weak_time_point_y(int cd) {
	characters[cd].time_point_for_movement_to_y = 10;
}
@}



Функция которая восстанавливает время до следующего хода
у всех персонажей в игре:

@d Character functions @{
@<Update time point for different characters@>

void characters_update_all_time_points(void) {
	int i;

	for(i = 0; i < characters_pos; i++)
		switch(characters[i].character_type) {
			case character_reimu:
				character_reimu_update_time_points(i);
				break;
			case character_marisa:
				character_marisa_update_time_points(i);
				break;
			@<characters_update_all_time_points other characters@>
			default:
				fprintf(stderr, "\nUnknown character\n");
				exit(1);
		}
}
@}
characters_update_all_time_points нужно вызывать в конце
каждого опроса перемещений ВСЕХ персонажей. Она восстанавливает очки перемещения у
всех персонажей, те после определённого количества вызовов этой функции,
персонажы смогут сделать один ход.

@d Character public prototypes @{@-
void characters_update_all_time_points(void);
@}

Реализация обновления времени до следующего хода у конкретного вида
персонажей:

@d Update time point for different characters @{
static void character_reimu_update_time_points(int cd) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x > 0)
		character->time_point_for_movement_to_x--;

	if(character->time_point_for_movement_to_y > 0)
		character->time_point_for_movement_to_y--; 
}

static void character_marisa_update_time_points(int cd) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x > 0)
		character->time_point_for_movement_to_x--;

	if(character->time_point_for_movement_to_y > 0)
		character->time_point_for_movement_to_y--;
}
@}



Сделаем ход всеми компьютерными персонажами. Вражеские персонажи которые спят или
мертвы пропускают ход.

@d Character functions @{
@<Helper functions@>
@<AI functions for different characters@>

void characters_ai_control(void) {
	int i;

	for(i = 0; i < characters_pos; i++) {
		CharacterList *character = &characters[i];

		if(character->hp <= 0 || character->is_sleep == 1)
			continue;

		switch(character->character_type) {
			case character_reimu:
				character_reimu_ai_control(i);
				break;
			case character_marisa:
				character_marisa_ai_control(i);
				break;
			@<characters_ai_control other characters@>
			default:
				fprintf(stderr, "\nUnknown character\n");
				exit(1);
		}
	}
}
@}

@d Character public prototypes @{@-
void characters_ai_control(void);
@}

Мозги для конкретных персонажей:
@d AI functions for different characters @{
static void character_reimu_ai_control(int cd) {
	CharacterList *character = &characters[cd];

	@<Reimu ai control@>
}

static void character_marisa_ai_control(int cd) {
	exit(1); // FIXME
}
@}


==============================================================

Вспомогательные функции.

character_move_to_point - движение к точке.
Каждый её вызов передвигает персонаж cd ближе к точке (x,y)

@d Helper functions @{
static void character_move_to_point(int cd, int x, int y) {
	CharacterList *character = &characters[cd];

	@<character_move_to_point params@>
	@<character_move_to_point is end of movement?@>
	@<character_move_to_point save start coordinate@>
	@<character_move_to_point calculate percent of movement@>
	@<character_move_to_point choose direction@>
}
@}

Проверим достигли мы конечной точки или нет:
@d character_move_to_point is end of movement? @{
if(character->x == x && character->y == y) {
	character->move_percent = 0;
	return;
}
@}
Мы не забыли установить процент движения move_percent в 0. Движения больше нет.


Если мы только начали движение, то нужно запомнить начальные координаты
движения:
@d character_move_to_point save start coordinate @{
if(character->move_percent == 0) {
	character->move_begin_x = character->x;
	character->move_begin_y = character->y;
}
@}
Можно считать, что move_percent = 100.

Посчитаем какой процент расстояния осталось пройти. Для этого поделим расстояние
до конечной точки на длину всего маршрута:
@d character_move_to_point calculate percent of movement @{
{
	int dx, dy;
	float all, last;

	dx = character->move_begin_x - x;
	dy = character->move_begin_y - y;
	@<character_move_to_point find correction coef@>

	all = sqrt(dx*dx + dy*dy);

	dx = character->x - x;
	dy = character->y - y;
	@<character_move_to_point correction coef at this time@>

	last = sqrt(dx*dx + dy*dy);

	character->move_percent = (int)((last/all) * 100.0);
}
@}
Поиски correction coef не относятся к этой задаче, зачем они написано ниже.
FIXME: возможно стоит перенести поиск процента оставшегося растояния в отдельную функцию,
а атрибут move_percent убрать. (+) освободим память, (-) чаще будем пересчитывать move_percent.

Добавим к структуре новые параметры:
@d Character struct param @{
int move_percent;
int move_begin_x;
int move_begin_y;
@}
move_percent - процент пути который осталось пройти. В конце пути он равен 0.
Для того чтобы сбросить старое движение и начать новое, нужно присвоить move_percent 0.
move_begin_x, move_begin_y - начальные координаты движения.


Найдем коэффициент с которого мы будем сверять отклонение от маршрута:
@d character_move_to_point find correction coef @{
if(dy == 0)
	correction_coef = 100.0;
else
	correction_coef = fabs((float)dx/(float)dy);
@}

@d character_move_to_point params @{
float correction_coef;
@}


Найдем значение этого же коффициента, но не для всего маршрута, а для
оставшейся части:
@d character_move_to_point correction coef at this time @{
if(dy == 0)
	now_coef = 100.0;
else
	now_coef = fabs((float)dx/(float)dy);
@}

@d character_move_to_point params @{
float now_coef;
@}


Выберем направление движения:
@d character_move_to_point choose direction @{
if(now_coef < correction_coef)
	fy = 1;
else if(now_coef > correction_coef)
	fx = 1;
else {
	fx = 1;
	fy = 1;
}

if(fx == 1 && character->x != x) {
	if(character->x > x)
		character_move_to(cd, character_move_to_left);
	else
		character_move_to(cd, character_move_to_right);
}

if(fy == 1 && character->y != y) {
	if(character->y > y)
		character_move_to(cd, character_move_to_up);
	else
		character_move_to(cd, character_move_to_down);
}
@}

@d character_move_to_point params @{
int fx = 0, fy = 0;
@}


===========================================================


Опишем поведение боссов.
Пусть оно пока храниться здесь, позже перенесу.

Нам понадобиться специальный параметр, который показывает какое
дествие совершается.

@d Character struct param @{
int step_of_movement;
@}

Добавим такую строку в функцию create всем персонажам:
character->step_of_movement = 0;


Босс движется из точки в точку. Достигает её. Мы изменяем step_of_movement,
чтобы знать какой шаг делать потом.

@d Character private structs @{
typedef struct {
	int x, y;
} Point;
@}

@d Reimu ai control @{
Point p[] = {{100, 100}, {200, 10}, {10, 200}, {200, 200}, {10, 10}};

if(character->step_of_movement == 5)
	character->step_of_movement = 0;

character_move_to_point(cd, p[character->step_of_movement].x, p[character->step_of_movement].y);

if(character->move_percent == 0) {
	character->step_of_movement++;
}
@}

Перемещаемся между точками.


В будущем нам могут понадобиться две переменные:
@d Character struct param @{
int move_x;
int move_y;
@}
Они требуются, когда нужно где-то сохранить точку куда двигается персонаж.
Используются в ai.

Иногда нужно ждать некоторое время, таймер можно хранить здесь:
@d Character struct param @{
int time;
@}

===========================================================

Функция которая рисует всех персонажей, которые не спят.
Стоит рисовать её до того как нарисовать рамку, чтобы рамка перекрыла
не полностью вылезших персонажей.
FIXME: Пока рисует всех, а не только не спящих.

@d Character functions @{
@<Draw functions for different characters@>

void characters_draw(void) {
	int i;

	for(i = 0; i < characters_pos; i++)
		switch(characters[i].character_type) {
			case character_reimu:
				character_reimu_draw(i);
				break;
			case character_marisa:
				character_marisa_draw(i);
				break;
			@<characters_draw other characters@>
			default:
				fprintf(stderr, "\nUnknown character\n");
				exit(1);
		}
}
@}

@d Character public prototypes @{@-
void characters_draw(void);
@}

Конкретные функции рисования для различных персонажей:

@d Draw functions for different characters @{
static void character_reimu_draw(int cd) {
	CharacterList *character = &characters[cd];
	static int id = -1;

	if(id == -1)
		id = image_load("aya.png");

	if(character->is_sleep == 1)
		return;

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.1);
}

static void character_marisa_draw(int cd) {
	CharacterList *character = &characters[cd];
	static int id = -1;

	if(id == -1)
		id = image_load("marisa.png");

	if(character->is_sleep == 1)
		return;

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.1);
}
@}


TODO: Есть одна мысль.
Уберем механизм стека и функцию character_create вместе с character_reimu, character_marisa.

Пусть у нас будет два этажа, напишем код создания монстров для них:

void level01(void) {
	enum {
		lvl01_main_hero, lvl01_fly_monster_1, lvl01_fly_monster_2, ...,
		lvl01_midboss, lvl01_fly_monster_10, ..., lvl01_boss
	};

	// character_main_hero_create(lvl01_main_hero);
	character_fly_monster_create(lvl01_fly_monster_1);
	character_fly_monster_create(lvl01_fly_monster_2);
	...
	character_night_bug_create(lvl01_midboss);
	character_fly_monster_create(lvl01_fly_monster_10);
	...
	character_sparow_create(lvl01_boss);

	character_list_pos = lvl01_boss + 1;
}

Создание главного героя закомментировано поскольку к этому моменту главный герой уже создан.

void level02(void) {

	enum {
		lvl02_main_hero, lvl02_yellow_fly_monster, lvl02_green_fly_monster, ...,
		lvl02_midboss, lvl02_pink_fly_monster, ..., lvl02_boss
	};

	character_yellow_fly_monster_create(lvl02_yellow_fly_monster);
	...
	character_list_pos = lvl02_boss + 1;
}

В конце мы задаем character_list_pos чтобы не проходить по всему массиву.

Этот механизм прост и даёт хорошую гибкость. Для пуль он малопригоден, но они,
в отличии от персонажей, удаляются.
С помощью такого механизма мы можем не бороться с дескрипторами и переносить в
следующий этаж только нужных персонажей.

======================================================================

Начнем добавлять персонажей:

Лунные феи.

Синие феи.

Добавим в список:
@d Character types @{@-
character_blue_moon_fairy,
@}

Функция создания персонажа:
@d Character functions @{
void character_blue_moon_fairy_create(int cd, int x, int y) {
	CharacterList *character = &characters[cd];

	character->x = x;
	character->y = y;
	character->hp = 100;
	character->is_sleep = 1;
	character->character_type = character_blue_moon_fairy;
	character->time_point_for_movement_to_x = 0;
	character->time_point_for_movement_to_y = 0;
	character->step_of_movement = 0;
	character->radius = 10;
}
@}
radius - радиус хитбокса.

@d Character public prototypes @{@-
void character_blue_moon_fairy_create(int cd, int x, int y);
@}

Функции установки time points после совершения перемещения:
@d character_set_weak_time_point_x other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_set_weak_time_point_x(cd);
	break;
@}

@d character_set_weak_time_point_y other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_set_weak_time_point_y(cd);
	break;
@}

@d Different characters set weak time_point functions @{
static void character_blue_moon_fairy_set_weak_time_point_x(int cd) {
	characters[cd].time_point_for_movement_to_x = 5;
}

static void character_blue_moon_fairy_set_weak_time_point_y(int cd) {
	characters[cd].time_point_for_movement_to_y = 5;
}
@}

Функции обновления time points:
@d characters_update_all_time_points other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_update_time_points(i);
	break;
@}

@d Update time point for different characters @{
static void character_blue_moon_fairy_update_time_points(int cd) {
	CharacterList *character = &characters[cd];

	if(character->time_point_for_movement_to_x > 0)
		character->time_point_for_movement_to_x--;

	if(character->time_point_for_movement_to_y > 0)
		character->time_point_for_movement_to_y--; 
}
@}

AI феи:
@d characters_ai_control other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_ai_control(i);
	break;
@}

@d AI functions for different characters @{
static void character_blue_moon_fairy_ai_control(int cd) {
	CharacterList *character = &characters[cd];
	@<character_blue_moon_fairy_ai_control move to down and center@>
	@<character_blue_moon_fairy_ai_control wait@>
	@<character_blue_moon_fairy_ai_control go away@>
	@<character_blue_moon_fairy_ai_control move and remove@>
}
@}

Перемещаемся поближе к центру(чуть выше) игрового поля. Чем персонаж ближе к центру в
начальный момент, тем ближе он подлетит в конце.
Для начала пройдём полмаршрута и выстрелим:
@d character_blue_moon_fairy_ai_control move to down and center @{
if(character->step_of_movement == 0) {
	character->move_x = GAME_FIELD_W/2 + (character->x - GAME_FIELD_W/2)/2;
	character->move_y = GAME_FIELD_H/2 - GAME_FIELD_H/4 + character->y;
	character->step_of_movement = 1;
}

if(character->step_of_movement == 1) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->move_percent < 50) {
		bullet_white_spray3_create(character->x, character->y);
		character->step_of_movement = 2;
	}
}
@}

Потом пройдем остаток маршрута и выстрелим:
@d character_blue_moon_fairy_ai_control move to down and center @{
if(character->step_of_movement == 2) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->move_percent == 0) {
		bullet_white_spray3_create(character->x, character->y);

		character->time = 500;
		character->step_of_movement = 3;
	}
}
@}

Ждем полсекунды(character->time выше):
@d character_blue_moon_fairy_ai_control wait @{
if(character->step_of_movement == 3) {
	character->time = timer_calc(character->time);
	if(character->time == 0)
		character->step_of_movement = 4;
}
@}

Улетаем за край экрана. Те что слева от центра улетают направо, те что
справа от центра налево:
@d character_blue_moon_fairy_ai_control go away @{
if(character->step_of_movement == 4) {
	character->move_x = character->x < GAME_FIELD_W/2 ? GAME_FIELD_W + 30 : -30;
	character->move_y = character->y - GAME_FIELD_H/5;
	character->step_of_movement = 5;
}
@}

Перемещаемся в (move_x, move_y). Стреляем на половине пути:
@d character_blue_moon_fairy_ai_control move and remove @{
if(character->step_of_movement == 5) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->move_percent < 50) {
		bullet_white_spray3_create(character->x, character->y);
		character->step_of_movement = 6;
	}
}
@}

Перемещаемся остаток пути. Убираем тех, кто достиг края экрана:
@d character_blue_moon_fairy_ai_control move and remove @{
if(character->step_of_movement == 6) {
	character_move_to_point(cd, character->move_x, character->move_y);
	if(character->x > GAME_FIELD_W+20 || character->x < -20) {
		character->is_sleep = 1;
		character->step_of_movement = 0;
		character->move_percent = 0;
	}
}
@}
Очищаем step_of_movement и move_percent.


Рисуем персонажа:
@d characters_draw other characters @{
case character_blue_moon_fairy:
	character_blue_moon_fairy_draw(i);
	break;
@}

@d Draw functions for different characters @{
static void character_blue_moon_fairy_draw(int cd) {
	CharacterList *character = &characters[cd];
	static int id = -1;

	if(id == -1)
		id = image_load("blue_fairy.png");

	if(character->is_sleep == 1)
		return;

	image_draw_center(id,
		GAME_FIELD_X + character->x,
		GAME_FIELD_Y + character->y,
		0, 0.4);
}
@}

Повреждение от пуль:
@d damage_calculate other enemy characters @{
case character_blue_moon_fairy:
	if(bullet->bullet_type == bullet_reimu_first)
		character->hp -= 1000;
	break;
@}
===========================================================

Игровой персонаж.

@o player.h @{
@<Player public structs@>
@<Player public prototypes@>
@}

@o player.c @{
#include <stdlib.h>
#include <stdio.h>

#include "player.h"

@<Player private macros@>
@<Player private structs@>
@<Player private prototypes@>
@<Player functions@>
@}

Координаты игрового персонажа(у обоих форм совпадают):
@d Player public structs @{
extern int player_x;
extern int player_y;
@}

@d Player private structs @{
int player_x;
int player_y;
@}


Тип игрового персонажа:
@d Player private structs @{
static int player_type;
@}

Доступные типы персонажей:
@d Player public structs @{
enum {
	player_reimu, player_yukari,
	player_marisa, player_alice,
	@<Player other player types@>
};
@}

Функция выбора команды из двух персонажей.
Её вызывают когда в игровом меню выбирают какой командой будут играть:
@d Player public prototypes @{
void player_select_team(int team);
@}

@d Player functions @{
void player_select_team(int team) {
	player_team = team;
	player_type = team*2;
	player_update_hitbox_radius();
}
@}
Используем свойство, что первый персонаж в команде имеет номер *2 от номера команды.
Обновим радиус хитбокса.

Функция проверяет тип персонажа и устанавливает нужный радиус хитбокса и радиус сбора
бонусов:
@d Player private prototypes @{
static void player_update_hitbox_radius(void) {
	switch(player_type) {
		case player_reimu:
			player_radius = 10;
			player_get_radius = 20;
			break;
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
}
@}

Радиус хитбокса и радиус сбора бонусов:
@d Player public structs @{
extern int player_radius;
extern int player_get_radius;
@}

@d Player private structs @{
int player_radius;
int player_get_radius;
@}



Объявим глобальную переменную в которой будем хранить тип команды:
@d Player private structs @{
static int player_team;
@}

Перечислим возможные команды:
@d Player public structs @{
enum {
	player_team_reimu,
	player_team_marisa,
	@<Player other player's teams@>
};
@}

Функции переключения персонажей:
@d Player public prototypes @{
void player_shadow_character(void);
void player_human_character(void);
@}

@d Player functions @{
void player_shadow_character(void) {
	if(player_type % 2 == 0)
		player_type++;
	player_update_hitbox_radius();
}

void player_human_character(void) {
	if(player_type % 2 == 1)
		player_type--;
	player_update_hitbox_radius();
}
@}
С помощью этих функции выбирается человек или ёкай.
Обновляем радиус хитбокса с помощью player_update_hitbox_radius.

Функция выстрела:
@d Player public prototypes @{
void player_fire(void);
@}

@d Player functions @{
@<Player update fires' time points@>

void player_fire(void) {
	switch(player_type) {
		@<player_fire players' fires@>
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}

	@<player_fire set weak time point@>
}
@}

@d Player private macros @{
#include "bullets.h"
@}

Атака Рейму:
@d player_fire players' fires @{
case player_reimu:
	if(player_time_point_first_fire == 0)
		bullet_player_reimu_first_create();

	break;
@}
player_time_point_first_fire - очки времени для первого типа пуль, когда они равны 0
персонаж может выпустить одну пулю.

@d Player private structs @{
static int player_time_point_first_fire;
@}

Когда player_time_point_first_fire становится равным 0, нужно увеличить его
чтобы он начал отсчёт до следующего выстрела:
@d player_fire set weak time point @{
if(player_time_point_first_fire == 0)
	player_time_point_first_fire = 80;
@}


Использование карты:
@d Player public prototypes @{
void player_use_card(void);
@}

@d Player functions @{
void player_use_card(void) {
	if(player_powers == 0)
		return;

	switch(player_type) {
		case player_reimu:
			//bullet_player_reimu_card_bullet();
			break;
		@<player_fire other players' card@>
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
	player_powers--;
}
@}
Уменьшаем количество карт.

Количество карт:
@d Player public structs @{
extern int player_powers;
@}

@d Player private structs @{
int player_powers;
@}

Очки времени, которые тратятся на перемещение:
@d Player private structs @{
static int player_time_point_for_movement_to_x;
static int player_time_point_for_movement_to_y;
@}

Функции для задания штрафа к time points:
@d Player functions @{
void player_set_weak_time_point_x(void) {
	switch(player_type) {
		case player_reimu:
		case player_marisa:
			player_time_point_for_movement_to_x = 5;
			break;
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
}

void player_set_weak_time_point_y(void) {
	switch(player_type) {
		case player_reimu:
		case player_marisa:
			player_time_point_for_movement_to_y = 5;
			break;
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
}
@}

Функции перемещения:
@d Player public prototypes @{
void player_move_to(int move_to);
@}

@d Player functions @{
void player_move_to(int move_to) {
	if(player_time_point_for_movement_to_x == 0) {
		if(move_to == player_move_to_left) {
			player_set_weak_time_point_x();
			player_x--;
		}
		else if(move_to == player_move_to_right) {
			player_set_weak_time_point_x();
			player_x++;
		}
	}

	if(player_time_point_for_movement_to_y == 0) {
		if(move_to == player_move_to_up) {
			player_set_weak_time_point_y();
			player_y--;
		}
		else if(move_to == player_move_to_down) {
			player_set_weak_time_point_y();
			player_y++;
		}
	}
}
@}

Перечислим направления перемещения:
@d Player public structs @{
enum {
	player_move_to_left, player_move_to_right, player_move_to_up, player_move_to_down
};
@}

Функция которая уменьшает time points, что в итоге приводит к тому, что
персонаж может сдвинуться на позицию и производить выстрелы:
@d Player public prototypes @{
void player_update_all_time_points(void);
@}

@d Player functions @{
void player_update_all_time_points(void) {
	if(player_time_point_for_movement_to_x > 0)
		player_time_point_for_movement_to_x--;

	if(player_time_point_for_movement_to_y > 0)
		player_time_point_for_movement_to_y--;

	if(player_time_point_first_fire > 0)
		player_time_point_first_fire--;
}
@}

Рисуем персонажей:
@d Player public prototypes @{
void player_draw(void);
@}

@d Player functions @{
void player_draw(void) {
	switch(player_type) {
		case player_reimu: {
			static int id = -1;

			if(id == -1)
				id = image_load("reimu.png");

			image_draw_center(id,
				GAME_FIELD_X + player_x,
				GAME_FIELD_Y + player_y,
				0, 0.8);
			
			break;
		}
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
}
@}

Число попыток до того как появится окно продолжений:
@d Player public structs @{
extern int player_players;
@}

@d Player private structs @{
int player_players;
@}


@d Player private macros @{
#include "os_specific.h"
#include "const.h"
#include "bonuses.h"
@}

Сбор бонусов при достижении линии:
@d Player public prototypes @{
void player_bonus_line(void);
@}

@d Player functions @{
void player_bonus_line(void) {
	switch(player_type) {
		@<player_bonus_line players@>
		default:
			fprintf(stderr, "\nUnknown player type\n");
			exit(1);
	}
}
@}

@d player_bonus_line players @{@-
case player_reimu:
	if(player_y < GAME_BONUS_LINE)
		move_visible_bonuses();
	break;
@}
===========================================================

Пули.

@o bullets.h @{
@<Bullet public macros@>
@<Bullet public structs@>
@<Bullet public prototypes@>
@}

@o bullets.c @{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "bullets.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"

@<Bullet private macros@>
@<Bullet private structs@>
@<Bullet private prototypes@>
@<Bullet functions@>
@}

Структура для хранения пуль:
@d Bullet public structs @{
typedef struct {
	int x;
	int y;
	float angle;
	int bullet_type;
	int is_noempty;
	@<Bullet params@>
} BulletList;
@}

x, y - коодинаты пули
angle - угол поворота
bullet_type - тип
is_noempty - не пустая ячейка для пули. Если флаг установлен, то эта ячейка занята.

Массив пуль:
@d Bullet public structs @{
extern BulletList bullets[BULLET_LIST_LEN];
@}

@d Bullet private structs @{
BulletList bullets[BULLET_LIST_LEN];
@}

BULLET_LIST_LEN - максимальное количество пуль

@d Bullet public macros @{
#define BULLET_LIST_LEN 2048
@}


Типы пуль:
@d Bullet public structs @{
enum {
	bullet_white,
	bullet_red,
	@<Bullet types@>
};
@}

Функция создания белой круглой пули:
@d Bullet functions @{
void bullet_white_create(int x, int y, float angle) {
	BulletList *bullet = bullet_get_free_cell();

	bullet->x = x;
	bullet->y = y;
	bullet->angle = angle;
	bullet->bullet_type = bullet_white;
	bullet->move_flag = 0;
}
@}

@d Bullet public prototypes @{
void bullet_white_create(int x, int y, float angle);
@}


bullet_get_free_cell - функция возвращающая свободный дескриптор.
Она устанавливает флаг is_noempty.
@d Bullet functions @{
static BulletList *bullet_get_free_cell(void) {
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++)
		if(bullets[i].is_noempty == 0) {
			bullets[i].is_noempty = 1;
			return &bullets[i];
		}

	fprintf(stderr, "\nBullet list is full\n");
	exit(1);
}
@}

@d Bullet private prototypes @{
static BulletList *bullet_get_free_cell(void);
@}


Функция создания красной круглой пули:
@d Bullet functions @{
void bullet_red_create(int x, int y, float shift_angle) {
	BulletList *bullet = bullet_get_free_cell();

	bullet->x = x;
	bullet->y = y;
	bullet->angle = shift_angle;
	bullet->bullet_type = bullet_red;
	bullet->move_flag = 0;

	bullet->is_enemys = 1;
}
@}
Пуля летит в сторону главного игрового персонажа.
Параметр shift_angle используется для задания отклонения пули от
игрового персонажа. Позже параметр angle начинает использоваться
как обычный угол для пули.
Пуля выпущена врагом, поэтому is_enemys = 1.


@d Bullet public prototypes @{
void bullet_red_create(int x, int y, float shift_angle);
@}



AI пуль:

@d Bullet public prototypes @{
void bullets_action(void);
@}

@d Bullet functions @{
@<Bullet action helpers@>
@<Bullet actions@>

void bullets_action(void) {
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++) {
		BulletList *bullet = &bullets[i];

		@<Skip cycle if bullet slot empty@>

		switch(bullet->bullet_type) {
			case bullet_white:
				bullet_white_action(i);
				break;
			case bullet_red:
				bullet_red_action(i);
				break;
			@<bullets_action other bullets@>
			default:
				fprintf(stderr, "\nUnknown bullet\n");
				exit(1);
		}
	}
}
@}

Пропустим один цикл for, если ячейка для пули пуста:
@d Skip cycle if bullet slot empty @{
if(bullet->is_noempty == 0)
	continue;
@}



Конкретые функции действия пуль.

Белая пуля делает круги:
@d Bullet actions @{
static void bullet_white_action(int bd) {
	BulletList *bullet = &bullets[bd];

	bullet_move_to_angle_and_radius(bd, bullet->angle, 10.0);

	if(bullet->move_flag == 0)
		bullet->angle += 5;
}
@}



Красная пуля улетает за край экрана по прямой.

Вычислим угол до персонажа, если пуля не перемещается и передадим в функцию
перемещения:
@d Bullet actions @{
static void bullet_red_action(int bd) {
	BulletList *bullet = &bullets[bd];

	if(bullet->move_flag == 0) {
		@<bullet_red_action calculate angle@>
	}

	@<bullet_red_action move bullet to player@>
	@<bullet_red_action destroy bullet@>
}
@}

Вычисляем угол между игроком и пулей с помощью арктангенса:
@d bullet_red_action calculate angle @{
int dx = player_x - bullet->x;
int dy = player_y - bullet->y;

bullet->angle += atan2(dy, dx)*(180.0/M_PI);
@}
atan2 корректно обрабатывает dx = 0.
У данного типа пуль параметр angle при создании пули используется как отклонение,
именно поэтому мы прибавляем к нему значение полученое от atan2, а не присваиваем.

Полученный угол angle мы используем чтобы направить пулю в направлении игрока:
@d bullet_red_action move bullet to player @{
bullet_move_to_angle_and_radius(bd, bullet->angle,
	GAME_FIELD_W * GAME_FIELD_H);
@}
Теперь пуля гарантировано улетит за край экрана.

bullet_move_to_angle_and_radius - переместить пулю по направлению angel на радиус W*H. Когда
пуля достигнет цели, то move_flag сбросится в 0.

Уничтожем пулю когда она вылетит за пределы экрана:
@d bullet_red_action destroy bullet @{
if(bullet->x < -25 || bullet->x > GAME_FIELD_W + 25 ||
	bullet->y < -25 || bullet->y > GAME_FIELD_H + 25)
	bullet->is_noempty = 0;
@}



Сложные пули делаются так: мы создаем "главную" пулю, которая создаёт дочерние.
Дочерние пули имеют номер дескриптора родителя. Родитель меняет у дочерних пуль параметр
step_of_movement и тем самым меняет их поведение. Родитель должен находится
раньше всех дочерних пуль, иначе замена местами двух пуль при удалении повредит его
дескриптор.
Не стоит забывать, что у пуль "нет" дескрипторов.


@d Bullet params @{
int move_flag;
float move_coef;
int move_x;
int move_y;
@}

move_flag - устанавливается в 0, если движение окончено. При начале движения этот флаг проверяется и
если он установлен, то продолжается старое движение. То есть чтобы начать новое движение нужно вначале
установить move_flag в 0, иначе будет продолжаться старое движение.


Это строка долна быть в функциях создания пуль:
bullet->move_flag = 0;


@d Bullet action helpers @{
static void bullet_move_to_angle_and_radius(int bd, float angle, float radius) {
	BulletList *bullet = &bullets[bd];

	if(bullet->move_flag == 0) {
		const double deg2rad = M_PI/180.0;
		bullet->move_x = bullet->x + (int)(radius*cos(angle*deg2rad));
		bullet->move_y = bullet->y + (int)(radius*sin(angle*deg2rad));
	}

	bullet_move_to_point(bd, bullet->move_x, bullet->move_y);
}
@}

После того как пуля пройдёт расстояние radius по направлению angle, флаг move_flag сбросится
в 0. Во время движения он будет равен 1. Это можно использовать в скриптах.
radius*cos(angle*deg2rad) пришлось приводить к int так как он давал погрешность и пуля не летала
по кругу, а улетала за край экрана.

@d Bullet private prototypes @{
static void bullet_move_to_point(int bd, int x, int y);
@}

@d Bullet functions @{
static void bullet_move_to_point(int bd, int x, int y) {
	BulletList *bullet = &bullets[bd];

	int dx = bullet->x - x;
	int dy = bullet->y - y;

	float k;

	int fx = 0, fy = 0;

	if(dx == 0 && dy == 0) {
		bullet->move_flag = 0;
		return;
	}

	if(dy == 0)
		k = 100.0;
	else
		k = fabs((float)dx/(float)dy);

	if(bullet->move_flag == 0) {
		bullet->move_flag = 1;
		bullet->move_coef = k;
	}

	if(k < bullet->move_coef)
		fy = 1;
	else if(k > bullet->move_coef)
		fx = 1;
	else {
		fx = 1;
		fy = 1;
	}

	if(fx == 1 && dx != 0) {
		if(dx > 0)
			bullet_move_to(bd, bullet_move_to_left);
		else
			bullet_move_to(bd, bullet_move_to_right);
	}

	if(fy == 1 && dy != 0) {
		if(dy > 0)
			bullet_move_to(bd, bullet_move_to_up);
		else
			bullet_move_to(bd, bullet_move_to_down);
	}
}
@}

Да, да. И Кнут и прочие плачут кровавыми слезами, так как тут явное нарушение DRY
и этот код повторяет код character_move_to_point. Кроме того будут повторены bullet_move_to
как character_move_to и все сопутствующее функции восстановления time points. Они были
сильно связаны со структорой CharacterList и поэтому я не рискнул делать их универсальными.
Можно лишь порадоваться тому, что здесь они будут static и скрыты внутри bullets.c

@d Bullet private structs @{
enum {
	bullet_move_to_left, bullet_move_to_right, bullet_move_to_up, bullet_move_to_down
};
@}

@d Bullet private prototypes @{
static void bullet_move_to(int bd, int move_to);
@}

@d Bullet functions @{
static void bullet_move_to(int bd, int move_to) {
	BulletList *bullet = &bullets[bd];

	if(bullet->time_point_for_movement_to_x == 0) {
		if(move_to == bullet_move_to_left) {
			bullet_set_weak_time_point_x(bd);
			bullet->x--;
		}
		else if(move_to == bullet_move_to_right) {
			bullet_set_weak_time_point_x(bd);
			bullet->x++;
		}
	}

	if(bullet->time_point_for_movement_to_y == 0) {
		if(move_to == bullet_move_to_up) {
			bullet_set_weak_time_point_y(bd);
			bullet->y--;
		}
		else if(move_to == bullet_move_to_down) {
			bullet_set_weak_time_point_y(bd);
			bullet->y++;
		}
	}
}
@}

Добавим в структуру пули нужные переменные:

@d Bullet params @{
int time_point_for_movement_to_x;
int time_point_for_movement_to_y;
@}

Зачем нужны эти параметры можно узнать выше в разделе character.

Сейчас определим bullet_set_weak_time_point_x и bullet_set_weak_time_point_y
аналогично character_set_weak_time_point_x и character_set_weak_time_point_y:

@d Bullet private prototypes @{
static void bullet_set_weak_time_point_x(int bd);
static void bullet_set_weak_time_point_y(int bd);
@}

@d Bullet functions @{
@<Set weak time points for concrete bullets@>
static void bullet_set_weak_time_point_x(int bd) {
	switch(bullets[bd].bullet_type) {
		case bullet_white:
			bullet_white_set_weak_time_point_x(bd);
			break;
		case bullet_red:
			bullet_red_set_weak_time_point_x(bd);
			break;
		@<bullet_set_weak_time_point_x other bullets@>
		default:
			fprintf(stderr, "\nUnknown bullet\n");
			exit(1);
	}
}

static void bullet_set_weak_time_point_y(int bd) {
	switch(bullets[bd].bullet_type) {
		case bullet_white:
			bullet_white_set_weak_time_point_y(bd);
			break;
		case bullet_red:
			bullet_red_set_weak_time_point_y(bd);
			break;
		@<bullet_set_weak_time_point_y other bullets@>
		default:
			fprintf(stderr, "\nUnknown bullet\n");
			exit(1);
	}
}
@}

Конкретные реализации функции восстановления очков времени для разных видов пуль:
@d Set weak time points for concrete bullets @{
static void bullet_white_set_weak_time_point_x(int bd) {
	bullets[bd].time_point_for_movement_to_x = 1;
}

static void bullet_white_set_weak_time_point_y(int bd) {
	bullets[bd].time_point_for_movement_to_y = 1;
}

static void bullet_red_set_weak_time_point_x(int bd) {
	bullets[bd].time_point_for_movement_to_x = 5;
}

static void bullet_red_set_weak_time_point_y(int bd) {
	bullets[bd].time_point_for_movement_to_y = 5;
}
@}

Функция восстановления time points:
@d Bullet public prototypes @{
void bullets_update_all_time_points(void);
@}

@d Bullet functions @{
void bullets_update_all_time_points(void) {
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++) {
		BulletList *bullet = &bullets[i];

		@<Skip cycle if bullet slot empty@>

		if(bullet->time_point_for_movement_to_x > 0)
			bullet->time_point_for_movement_to_x--;

		if(bullet->time_point_for_movement_to_y > 0)
			bullet->time_point_for_movement_to_y--; 
	}
}
@}

Нарисуем пули:
@d Bullet public prototypes @{
void bullets_draw(void);
@}

@d Bullet functions @{
@<Concrete functions for bullets drawing@>
void bullets_draw(void) {
	int i;

	for(i = 0; i < BULLET_LIST_LEN; i++) {
		BulletList *bullet = &bullets[i];

		@<Skip cycle if bullet slot empty@>

		switch(bullet->bullet_type) {
			case bullet_white:
				bullet_white_draw(i);
				break;
			case bullet_red:
				bullet_red_draw(i);
				break;
			@<bullets_draw other bullets@>
			default:
				fprintf(stderr, "\nUnknown bullet\n");
				exit(1);
		}
	}
}
@}

Рисуем конкретные:
@d Concrete functions for bullets drawing @{
static void bullet_white_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_green.png");

	image_draw_center(id,
		GAME_FIELD_X + bullets[bd].x,
		GAME_FIELD_Y + bullets[bd].y,
		bullets[bd].angle+90, 0.3);
}

static void bullet_red_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_green.png");

	image_draw_center(id,
		GAME_FIELD_X + bullets[bd].x,
		GAME_FIELD_Y + bullets[bd].y,
		bullets[bd].angle+90, 0.3);
}
@}

У пуль спрайт повёрнут на 90 градусов, исправляем.

==========================================================

Различные пули.


Веер пуль(spray).

Выпускает веер из 3-х белых круглых пуль по игроку.
Функция создания:
@d Bullet functions @{
void bullet_white_spray3_create(int x, int y) {
	bullet_red_create(x, y, 0.0);
	bullet_red_create(x, y, 4.0);
	bullet_red_create(x, y, -4.0);
}
@}

@d Bullet public prototypes @{
void bullet_white_spray3_create(int x, int y);
@}


Первый вид пуль Рейму, карты летящие вперёд.
@d Bullet functions @{
void bullet_player_reimu_first_create(void) {
	BulletList *bullet = bullet_get_free_cell();

	bullet->x = player_x;
	bullet->y = player_y;
	//bullet->angle = shift_angle;
	bullet->bullet_type = bullet_reimu_first;
	bullet->move_flag = 0;

	bullet->is_enemys = 0;
}
@}

@d Bullet public prototypes @{
void bullet_player_reimu_first_create(void);
@}

Добавим тип пули:
@d Bullet types @{@-
bullet_reimu_first,
@}

Карты летят снизу вверх за пределы экрана:
@d Bullet actions @{
static void bullet_reimu_first_action(int bd) {
	BulletList *bullet = &bullets[bd];

	@<bullet_reimu_first_action set move_x@>
	@<bullet_reimu_first_action move bullet@>
	@<bullet_reimu_first_action destroy bullet@>
}
@}

Пуля только что была создана, запомним положение персонажа который её выпустил:
@d bullet_reimu_first_action set move_x @{
if(bullet->move_flag == 0)
	bullet->move_x = player_x;
@}

Начнем перемещать пулю в этом направлении:
@d bullet_reimu_first_action move bullet @{
bullet_move_to(bd, bullet_move_to_up);
@}

Уничтожим пулю когда она выйдет за пределы экрана:
@d bullet_reimu_first_action destroy bullet @{
if(bullet->y < -25)
	bullet->is_noempty = 0;
@}

Добавим функцию поведения пули в диспетчер:
@d bullets_action other bullets @{@-
case bullet_reimu_first:
	bullet_reimu_first_action(i);
	break;
@}

Функции для установки очков времени для пули:
@d Set weak time points for concrete bullets @{
static void bullet_reimu_first_set_weak_time_point_x(int bd) {
	bullets[bd].time_point_for_movement_to_x = 1;
}

static void bullet_reimu_first_set_weak_time_point_y(int bd) {
	bullets[bd].time_point_for_movement_to_y = 1;
}
@}

Добавим эти функции в диспетчеры:
@d bullet_set_weak_time_point_x other bullets @{
case bullet_reimu_first:
	bullet_reimu_first_set_weak_time_point_x(bd);
	break;
@}

@d bullet_set_weak_time_point_y other bullets @{
case bullet_reimu_first:
	bullet_reimu_first_set_weak_time_point_y(bd);
	break;
@}

Рисуем летящие карты Рейму:
@d Concrete functions for bullets drawing @{
static void bullet_reimu_first_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bullet_white_card.png");

	image_draw_center(id,
		GAME_FIELD_X + bullets[bd].x,
		GAME_FIELD_Y + bullets[bd].y,
		0, 0.6);
}
@}

Добавим функцию рисования в диспетчер:
@d bullets_draw other bullets @{
case bullet_reimu_first:
	bullet_reimu_first_draw(i);
	break;
@}

Повреждение от пули:
@d bullet_collide other bullets @{
case bullet_reimu_first:
	if(is_rad_collide(x, y, radius, bullet->x, bullet->y, 10) == 0)
	  	break;
	bullet->is_noempty = 0;
	return 1;
@}
==========================================================

Повреждения от пуль.


Эту часть попробую написать топорным методом.
Есть функция которая ничего не принимает и не возвращает. Имеет прямой доступ к
списку пуль и персонажей. Сама функция вызывает только функции проверки пересечения
окружностей персонажей и пуль, вычитание жизней и проверку на имунитет к пулям
производит сама.

Так как она распухнет, то поместим её в отдельный модуль.

@o damage.h @{
void damage_calculate(void);
@}

@o damage.c @{
@<Damage header@>

#include "damage.h"

void damage_calculate(void) {
	@<damage_calculate body@>
}
@}

Стандартные хедеры:
@d Damage header @{
#include <stdio.h>
#include <stdlib.h>
@}

Нам нужен доступ к списку пуль и списку вражеских персонажей и персонажем игрока:
@d Damage header @{
#include "characters.h"
#include "bullets.h"
#include "player.h"
@}

Функция перебирает всех персонажей, перебирает все пули,
передаёт хитбоксы персонажей внутрь функции проверки пересечения пули,
фукнция пересечения возвращает истину или ложь, мы проверяем особые случаи повреждения и
отнимаем у персонажа сколько нужно жизней:
@d damage_calculate body @{
int i, j;

for(i = 0; i < BULLET_LIST_LEN; i++) {
	BulletList *bullet = &bullets[i];

	@<Skip cycle if bullet slot empty@>

	@<damage_calculate is enemy's bullet?@>

	for(j = 0; j < characters_pos; j++) {
		CharacterList *character = &characters[j];

		@<damage_calculate character hp=0 or is_sleep=1@>

		@<damage_calculate collision check@>
		@<damage_calculate character's damage unique@>

		@<damage_calculate if hp<0 then character died@>
	}
}
@}

Проверяемый персонаж уже мертв или спит и не выводится на экран:
@d damage_calculate character hp=0 or is_sleep=1 @{
if(character->hp <= 0 || character->is_sleep == 1)
	continue;
@}

Если пуля выпущена врагом, то проверим пересечение с персонажем игрока,
иначе перейдем к проверке вражеских персонажей:
@d damage_calculate is enemy's bullet? @{
if(bullet->is_enemys == 1) {
	if(bullet_collide(i, player_x, player_y, player_radius) == 1) {
		@<damage_calculate check collision with player@>
	}
	continue;
}
@}

Если пересечение было, то уменьшаем число попыток, если попыток больше нет,
то выводим continue-окно:
@d damage_calculate check collision with player @{
if(player_players == 0) {
	fprintf(stderr, "continue-window stub\n");
	exit(1);
}
player_players--;
@}


Проверка пересечения:
@d damage_calculate collision check @{
if(bullet_collide(i, character->x, character->y, character->radius) == 0)
	continue;
@}

Особенности повреждения различных вражеских персонажей:
@d damage_calculate character's damage unique @{
switch(character->character_type) {
	case character_reimu:
//		if(bullet->bullet_type == bullet_red)
			character->hp = 0;
		break;
	@<damage_calculate other enemy characters@>
	default:
		fprintf(stderr, "\nUnknown character\n");
		exit(1);
}
@}

Если у персонажа нет жизней, то отметить is_sleep:
@d damage_calculate if hp<0 then character died @{
if(character->hp <= 0) {
	character->hp = 0;
	character->is_sleep = 1;
}
@}
Флаг устанавливается для всех персонажей, у кого hp <= 0,
вне зависимости от того "умерли" ли они сейчас или давно.


Напишем функцию bullet_collide:
@d Bullet public prototypes @{
int bullet_collide(int bd, int x, int y, int radius);
@}
Принимает дискриптор пули, координаты хитбокса персонажа и радиус хитбокса.

@d Bullet functions @{
int bullet_collide(int bd, int x, int y, int radius) {
	BulletList *bullet = &bullets[bd];

	switch(bullet->bullet_type) {
		case bullet_white:
		case bullet_red:
			@<bullet_collide if bullet_red collide@>
		@<bullet_collide other bullets@>
		default:
			fprintf(stderr, "\nUnknown bullet\n");
			exit(1);
	}

	return 0;
}
@}

Проверим красную пулю на пересечение. Если его небыло то выходим из switch, позже
вызовется return 0. Иначе уничтожаем пулю и возвращаем 1.
@d bullet_collide if bullet_red collide @{
if(is_rad_collide(x, y, radius, bullet->x, bullet->y, 3) == 0)
	break;
bullet->is_noempty = 0;
return 1;
@}


Для доступа к is_rad_collide добавим хедер:
@d Bullet private macros @{
#include "collision.h"
@}

Добавим параметр is_enemys:
@d Bullet params @{
int is_enemys;
@}
Если он установлен, то пуля выпущена врагом.

Добавим радиус хитбокса для персонажей:
@d Character struct param @{
int radius;
@}

=========================================================

Игровые этажи.

@o levels.h @{
@<Levels prototypes@>
@}

@o levels.c @{
#include <stdio.h>
#include <stdlib.h>

#include "levels.h"

@<Levels macros@>
@<Levels structs@>
@<Levels functions@>
@}

Надо придумать удобный и главное простой скриптовый язык.

Какие возможности нужно заложить в него?
1.1) установку флага is_sleep у персонажа через N'ое время после установки(или сброса)
	is_sleep у другого персонажа
1.2) установку флага is_sleep у персонажа после смерти другого персонажа
2.1) вызов окна диалогов через N'ое время после установки(или сброса)
	is_sleep у вражеского персонажа
2.2) вызов окна диалогов после смерти вражеского персонажа

Все эти действия можно написать на pure C и при этом не прибегать к сложным механизмам.
Для этого надо сделать всё также как и при реализации ai персонажей или поведения
пуль. Заведем счетчик действий step_of_movement, а вместо move_flag(move_percent) будем использовать
is_sleep различных персонажей.

Напишем пример. Пусть вначале появляются два монстра(mon1, mon2), после их смерти
появляется босс(mon3), а после его смерти появляется диалог. Диалог блокирует выполнение
ai и перемещение пуль, поэтому рассматривать появление монстров после диалога не имеет
смысла.

static int step_of_movement;

void level_dispatcher(void) {
	...
	level01();
	...
}

static void level01(void) {
	switch(step_of_movement) {
		case 0:
			character_set_active(mon1);
			character_set_active(mon2);
			step_of_movement++;
			break;
		case 1:
			if(character_get_health_percent(mon1) != 0 ||
				character_get_health_percent(mon2) != 0)
				break;
			character_set_active(mon3);
			step_of_movement++;
			break;
		case 2:
			if(character_get_health_percent(mon3) != 0)
				break;
			dialog_function();
			step_of_movement++;
		.........................
		case 10:
			next_level();
			step_of_movement = 0;
			break;
	}
}

Конечно в такой форме скрипт не очень понятен, но lp позволит сделать его понятнее.
character_get_health_percent, dialog_function, next_level выдуманые функции. Возможно вместо них
будут другие. Например вместо character_get_health_percent можно, в большинстве случаев, использовать
более удобную character_is_died. Диалог скорее всего будет вызываться не dialog_function, а какой-нибудь
функцией с параметром-номером диалога. next_level будет менять глобальную статическую переменную,
скорее всего она же будет делать step_of_movement = 0 и нам не придётся писать это каждый раз самому.

В самом деле, когда нам может понадобиться менять step_of_movement не стандартным образом?
Например мы хотим сделать следующий этаж, продолжением старого этажа, с сохранением всех монстров.
Но для этого мы можем старых монстров сделать глобальными переменными и перенести в следующий этаж.
Кроме того при вызове next_level возможна очистка стеков пуль и персонажей, и чтобы не удалять всех
персонажей, а оставить тех, за кого играем мы, нужно завести в структуре персонажей флаг "не удалять".
Этот флаг нам позволит удалить персонажей, которые нам не пригодились, но небыли убиты или сохранить
убитых, если они нам могут пригодиться(например чтобы их оживить).

В этом примере нет таймера. Мы просто можем отсчитывать step_of_movement, но level может вызываться с
непредсказуемым интервалом. Для удобной работы с таймерами нам нужен стек таймеров, такой же как у
пуль или персонажей. В нем будут храниться таймеры с дескрипторами. В конце этажа таймеры не помеченые
как нужные к сохранению будут удаляться(механизм как у персонажей).
Таймеры нужны не только для скриптов, но я для отсчета действия карт, а возможно и для других игровых
задумок.


===================================================================

Задники.


Задники рисуются в первую очередь. Они трехмерные. На них расположены объекты,
например деревья. Должны отслуживать процент прохождения этажа и менятся при
этом, например изменяется освещённость.


Функция изменения стиля задника:
@d Background public prototypes @{
void background_set_type(int type);
@}

@d Background functions @{
void background_set_type(int type) {
	background_type = type;
	background_animation = 0;
}
@}

background_animation - переменная в которой хранится сдвиг задника при
анимации:
@d Background private structs @{
static int background_animation;
@}

В этой переменной будем хранить стиль задника:
@d Background private structs @{
static int background_type;
@}

Список доступных задников:
@d Background public structs @{
enum {
	background_forest,
	@<Background other types@>
};
@}

Функция которая изменяет значение background_animation и тем самым задаёт анимацию:
@d Background public prototypes @{
void background_update_animation(void);
@}

@d Background functions @{
void background_update_animation(void) {
	switch(background_type) {
		@<background_update_animation backgrounds@>
		default:
			fprintf(stderr, "\nUnknown background\n");
			exit(1);
	}
}
@}

Опишем значение "background_update_animation backgrounds" для магического леса:
@d background_update_animation backgrounds @{
case background_forest: {
	background_animation++;

	if(background_animation == 1280)
		background_animation = 0;
	break;
}
@}
Берем в учёт что размер текстуры леса 256x256, умножаем на 5, получаем 1280.

Функция принимающая процент прохождения этажа и меняющая задник:
@d Background public prototypes @{
void background_set_percent(int per);
@}

@d Background functions @{
void background_set_percent(int per) {
	background_percent = per;
}
@}

Переменная в которой хранится процент пройденности этажа:
@d Background private structs @{
static int background_percent;
@}

Функция рисования задника:
@d Background public prototypes @{
void background_draw(void);
@}

@d Background functions @{
void background_draw(void) {

	background_update_animation();

	window_set_3dbackground_config();

	switch(background_type) {
		@<background_draw backgrounds@>
		default:
			fprintf(stderr, "\nUnknown background\n");
			exit(1);
	}

	window_set_2d_config();
}
@}
window_set_3d_config, window_set_2d_config - удобные настройки окна(OGL) для
вывода соответствующей графики.


Настройки OGL для вывода 3D задника:
@d Background functions @{

static void gluPerspective(GLdouble fovy, GLdouble aspect, GLdouble zNear, GLdouble zFar)
{
   GLdouble xmin, xmax, ymin, ymax;

   ymax = zNear * tan(fovy * M_PI / 360.0);
   ymin = -ymax;

   xmin = ymin * aspect;
   xmax = ymax * aspect;

   glFrustum(xmin, xmax, ymin, ymax, zNear, zFar);
}

static void window_set_3dbackground_config(void) {
	glClearColor(0, 0, 0, 0);
	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

//	glDisable(GL_TEXTURE_2D);
	glEnable(GL_DEPTH_TEST);

	@<window_set_2d_config OGL blend@>

	glViewport(GAME_FIELD_X, GAME_FIELD_Y, GAME_FIELD_W, GAME_FIELD_H);

	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();

	gluPerspective(45.0f, ((float)GAME_FIELD_W)/((float)GAME_FIELD_H), 1.0f, 500.0f);
	//glFrustum(0, GAME_FIELD_W, GAME_FIELD_H, 0, 1.0, 1000.0);
	//glFrustum(0.0, 10.0, 10.0, 0.0, 1.0, 50.0);

	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
}
@}
Возможно стоит избавится от gluPerspective как от единственного glu.

@d Background private prototypes @{
static void window_set_3dbackground_config(void);
@}


Рисуем лес:
@d background_draw backgrounds @{
case background_forest: {
	static int id = -1;

	if(id == -1)
		id = image_load("forest.png");

	glTranslatef(0, 0, -1.5);
	glRotatef(-30, 1.0, 0.0, 0.0);
//	glScalef(scale, scale, 0);

	glBindTexture(GL_TEXTURE_2D, image_list[id].tex_id);

	@<background_draw draw background of forest@>
	@<background_draw draw trees@>
	break;
}
@}

Рисуем задник леса:
@d background_draw draw background of forest @{
{
	float shift = background_animation/256.0;

	glBegin(GL_QUADS);
		glTexCoord2f(0, 0.0 + shift);
		glVertex2i(-1, -1);

		glTexCoord2f(1, 0.0 + shift);
		glVertex2i(1, -1);

		glTexCoord2f(1, 1.0 + shift);
		glVertex2i(1, 1);

		glTexCoord2f(0, 1.0 + shift);
		glVertex2i(-1, 1);
	glEnd();
}
@}
shift - смещение текстуры, 256 - её размер.

Рисуем деревья:
@d background_draw draw trees @{
{
	int i;

	const Tree trees[] = {
		{100, 1346, 0},
		{160, 1298, 2}, {100, 1280, 0},
		{180, 1172, 0}, {130, 1050, 1},
		{140, 276, 1},
		{180, 272, 3}, {130, 270, 1},
		{160, 168, 2},
		{100, 66, 0},
		{160, 18, 2}, {100, 0, 0},};

	static int tree_id[4] = {-1, -1, -1, -1};

	if(tree_id[0] == -1)
		tree_id[0] = image_load("tree1.png");
	if(tree_id[1] == -1)
		tree_id[1] = image_load("tree2.png");
	if(tree_id[2] == -1)
		tree_id[2] = image_load("tree3.png");
	if(tree_id[3] == -1)
		tree_id[3] = image_load("tree4.png");


	for(i=0; i < sizeof(trees)/sizeof(Tree); i++) {
		glLoadIdentity();

		glTranslatef(0, 0, -1.45);
		glRotatef(-30, 1.0, 0.0, 0.0);
		glTranslatef(trees[i].x/128.0 - 1.0,
			(trees[i].y - background_animation)/128.0, 0);
		glRotatef(210, 1.0, 0.0, 0.0);
		glScalef(0.1, 0.1, 0);

		glBindTexture(GL_TEXTURE_2D, image_list[tree_id[trees[i].type]].tex_id);

		glBegin(GL_QUADS);
			glTexCoord2i(0, 0);
			glVertex2i(-1, -1);
		 
			glTexCoord2f(1, 0);
			glVertex2i(1, -1);
		 
			glTexCoord2f(1, 1);
			glVertex2i(1, 1);
		 
			glTexCoord2f(0, 1);
			glVertex2i(-1, 1);
		glEnd();
	}
}
@}
С координатами деревьев полный отстой. Длина хозяйства 1280. Если кто-то
находится в пределах 0-128, то нужно дублировать прибавив это к 1280.

Создадим структуру Tree в которой будут храниться деревья для задников:
@d Background private structs @{
typedef struct {
	int x;
	int y;
	int type;
} Tree;
@}

Файлы задников:
@o os_specific.h @{
@<Background public structs@>
@<Background public prototypes@>
@}

@o os_specific.c @{

//#include <GL/gl.h>
//#include <GL/glu.h>

//#include <stdio.h>
//#include <stdlib.h>

#include "const.h"
//#include "os_specific.h"

@<Background private structs@>
@<Background private prototypes@>
@<Background functions@>
@}

===================================================================

Таймеры.


@o timers.c @{
#include <stdio.h>
#include <stdlib.h>

#include <SDL.h>

#include "timers.h"

@<Timer private structs@>
@<Timer functions@>
@}


Для начала напишим функцию которая запоминает текущее значение таймера.
Её нужно будет вызывать раз в цикл.
@o timers.h @{
void timer_get_time(void);
@}

@d Timer functions @{
void timer_get_time(void) {
	last = new;
	new = SDL_GetTicks();
	if(last == 0)
		last = new;
}
@}
У нас есть значение new от прошлого вызова функции(new - значение таймера). Присвоим его last:
last = new;

Теперь мы можем поместить в new новое значение таймера(значение текущего вызова функции):
new = SDL_GetTicks();

Так как при первом вызове функции new=0, то и last теперь 0. Это нехорошо, так как new-last очень
большое число. Исправим это:
if(last == 0)
	last = new;


Для функции нужны два поля. В одном будет хранится текущее значение таймера, а в другой прошлое:
@d Timer private structs @{
static int new;
static int last;
@}

Теперь напишем функцию для пересчетай таймеров. Она принимает время которое осталось до
завершения работы таймера, вычитает из него время new-last и возвращает его. Функция
всегда возвращает значение >=0.
@o timers.h @{
int timer_calc(int time);
@}

@d Timer functions @{
int timer_calc(int time) {
	time = time - (new - last);
	if(time < 0)
		time = 0;

	return time;
}
@}

Пример использования:
	static int timer;

	while(1) {
		timer_get_time();

		timer = timer_calc(timer);
		if(timer == 0) {
			printf("Alarm!");
			timer = 100;
		}
	}


=========================================================

Бонусы.

После гигантского временнОго промежутка, продолжаю писать. Поэтому более
категорично относится к ошибкам.(тут вообще смесь кода из bullet и character)

Что можно сказать о бонусах?
	1)Они появляются за пределами экрана или на месте убитых монстров;
	2)Они самостоятельно исчезают попав за край экрана;
	3)Есть специальная линия на экране достигнув которой главный персонаж собирает
все бонусы;
	4)Про уничтожение бонусов я не помню, надо уточнить это;
	5)Скрипты не оказывают влияния на бонусы, и поэтому им не нужен id.
	6)После появления бонусы летят вверх, потому начинаю лететь вниз. А после пересечения
спецлинии по параболе к главному персонажу.

Отсутствие id делает бонусы похожими на пули.

@o bonuses.h @{
@<Bonus public macros@>
@<Bonus public structs@>
@<Bonus public prototypes@>
@}

@o bonuses.c @{
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

#include "bonuses.h"
#include "os_specific.h"
#include "const.h"
#include "player.h"
#include "collision.h"

@<Bonus private macros@>
@<Bonus private structs@>
@<Bonus private prototypes@>
@<Bonus functions@>
@}

Структура для хранения бонусов:

@d Bonus public structs @{
typedef struct {
	int x;
	int y;
	int type;
	int is_noempty;
	@<Bonuses params@>
} BonusList;
@}

x, y - координаты бонуса;
type - тип бонуса;
is_noempty - занятость слота; если не ноль, то занят.

Массив бонусов:
@d Bonus public structs @{
extern BonusList bonuses[BONUS_LIST_LEN];
@}

@d Bonus private structs @{
BonusList bonuses[BONUS_LIST_LEN];
@}

BONUS_LIST_LEN - максимальное количество бонусов

@d Bonus public macros @{
#define BONUS_LIST_LEN 2048
@}

Типы бонусов:
@d Bonus public structs @{
enum {
	bonus_small_score,
	bonus_medium_score,
	bonus_power,
	@<Bonus types@>
};
@}
Бонусы дающие очки и бонус увеличивающий мощность.

Функции создания бонусов:
@d Bonus functions @{
void bonus_small_score_create(int x, int y) {
	BonusList *bonus = bonus_get_free_cell();

	bonus->x = x;
	bonus->y = y;
	bonus->move_percent = 0;
	bonus->move_step = 0;
	bonus->move_to_player = 0;
	bonus->type = bonus_small_score;
}

void bonus_medium_score_create(int x, int y) {
	BonusList *bonus = bonus_get_free_cell();

	bonus->x = x;
	bonus->y = y;
	bonus->move_percent = 0;
	bonus->move_step = 0;
	bonus->move_to_player = 0;
	bonus->type = bonus_medium_score;
}

void bonus_power_create(int x, int y) {
	BonusList *bonus = bonus_get_free_cell();

	bonus->x = x;
	bonus->y = y;
	bonus->move_percent = 0;
	bonus->move_step = 0;
	bonus->move_to_player = 0;
	bonus->type = bonus_power;
}
@}

@d Bonus public prototypes @{@-
void bonus_small_score_create(int x, int y);
void bonus_medium_score_create(int x, int y);
void bonus_power_create(int x, int y);
@}


bonus_get_free_cell - функция возвращающая свободный дескриптор.
Она устанавливает флаг is_noempty.
@d Bonus functions @{
static BonusList *bonus_get_free_cell(void) {
	int i;

	for(i = 0; i < BONUS_LIST_LEN; i++)
		if(bonuses[i].is_noempty == 0) {
			bonuses[i].is_noempty = 1;
			return &bonuses[i];
		}

	fprintf(stderr, "\nBonus list is full\n");
	exit(1);
}
@}

@d Bonus private prototypes @{@-
static BonusList *bonus_get_free_cell(void);
@}

Поведение бонусов:

@d Bonus public prototypes @{@-
void bonuses_action(void);
@} 

@d Bonus functions @{
@<Bonus action helpers@>
@<Bonus actions@>

void bonuses_action(void) {
	int i;

	for(i = 0; i < BONUS_LIST_LEN; i++) {
		BonusList *bonus = &bonuses[i];

		@<Skip cycle if bonus slot empty@>

		switch(bonus->type) {
			case bonus_small_score:
				bonus_small_score_action(i);
				break;
			case bonus_medium_score:
				//bonus_medium_score_action(i);
				bonus_small_score_action(i);
				break;
			case bonus_power:
				//bonus_power_action(i);
				bonus_small_score_action(i);
				break;
			@<bonuses_action other bonuses@>
			default:
				fprintf(stderr, "\nUnknown bonus\n");
				exit(1);
		}
	}
}
@}

Пропустим один цикл for, если ячейка для бонуса пуста:
@d Skip cycle if bonus slot empty @{@-
if(bonus->is_noempty == 0)
	continue;
@}

Конкретные функции действия пуль.
@d Bonus actions @{
static void bonus_small_score_action(int bd) {
	BonusList *bonus = &bonuses[bd];

	@<bonus_small_score_action move to player@>

	@<bonus_small_score_action move up@>
	@<bonus_small_score_action move down@>
	@<bonus_small_score_action remove@>
}
@}
Как и обговаривалось ранее, пуля летит вверх(всё медленнее), потом вниз,
а потом её удаляют из списка.
@<bonus_small_score_action move to player@> - будет описан ниже,
он описывает движение бонуса к игроку, когда он встал на спецлинию.

Добавим с структуру бонусов два вспомогательных параметра:
@d Bonuses params @{@-
int move_percent;
int move_step;
@}
move_percent - процент пути который осталось пройти. В конце пути равен 0.
move_step - тип совершаемого действия, нужен для совершения сложного движения.

При создании бонуса нужно обнулять оба параметра move_percent и move_step.

@d bonus_small_score_action move up @{@-
if(bonus->move_step == 0) {
	bonus->move_x = bonus->x;
	bonus->move_y = bonus->y - 40;
	bonus->move_step = 1;
}

if(bonus->move_step == 1) {
	bonus_move_to_slower(bd, bonus->move_x, bonus->move_y);

	if(bonus->move_percent == 0)
		bonus->move_step = 2;
}
@}
bonus_move_to_slower - двигаться в направлении с замедлением.

@d bonus_small_score_action move down @{
if(bonus->move_step == 2) {
	bonus_move_to_direction(bd, bonus_move_to_down);
}
@}

@d bonus_small_score_action remove @{
if(bonus->x < -25 || bonus->x > GAME_FIELD_W + 25 ||
	bonus->y < -25 || bonus->y > GAME_FIELD_H + 25)
	bonus->is_noempty = 0;
@}



@d Bonuses params @{
int move_x;
int move_y;

int speed;

int time_point_for_movement_to_x;
int time_point_for_movement_to_y;
@}
move_x, move_y - точки куда перемещается бонус.
speed - скорость перемещения(0 - нормальная, 100 - максимальная)
time_point_for_movement_to_x, time_point_for_movement_to_y - очки перемещения,
				перемещение возможно, если этот параметр равен 0.

Напишем функцию востанавливающую time points:
@d Bonus functions @{
@<Set weak time points for concrete bonuses@>
static void bonus_set_weak_time_point_x(int bd) {
	switch(bonuses[bd].type) {
		case bonus_small_score:
			bonus_small_score_set_weak_time_point_x(bd);
			break;
		case bonus_medium_score:
			//bonus_medium_score_set_weak_time_point_x(bd);
			bonus_small_score_set_weak_time_point_x(bd);
			break;
		case bonus_power:
			//bonus_power_score_set_weak_time_point_x(bd);
			bonus_small_score_set_weak_time_point_x(bd);
			break;
		@<bonus_set_weak_time_point_x other bonuses@>
		default:
			fprintf(stderr, "\nUnknown bonus\n");
			exit(1);
	}
}

static void bonus_set_weak_time_point_y(int bd) {
	switch(bonuses[bd].type) {
		case bonus_small_score:
			bonus_small_score_set_weak_time_point_y(bd);
			break;
		case bonus_medium_score:
			//bonus_medium_score_set_weak_time_point_y(bd);
			bonus_small_score_set_weak_time_point_y(bd);
			break;
		case bonus_power:
			//bonus_power_score_set_weak_time_point_y(bd);
			bonus_small_score_set_weak_time_point_y(bd);
			break;
		@<bonus_set_weak_time_point_x other bonuses@>
		default:
			fprintf(stderr, "\nUnknown bonus\n");
			exit(1);
	}
}
@}

@d Set weak time points for concrete bonuses @{
static void bonus_small_score_set_weak_time_point_x(int bd) {
	BonusList *b = &bonuses[bd];
	b->time_point_for_movement_to_x = 5 - (b->speed / 30);
}

static void bonus_small_score_set_weak_time_point_y(int bd) {
	BonusList *b = &bonuses[bd];
	b->time_point_for_movement_to_y = 5 - (b->speed / 30);
}
@}

@d Bonus functions @{
void bonuses_update_all_time_points(void) {
	int i;

	for(i = 0; i < BONUS_LIST_LEN; i++) {
		BonusList *bonus = &bonuses[i];

		@<Skip cycle if bonus slot empty@>

		if(bonus->time_point_for_movement_to_x > 0)
			bonus->time_point_for_movement_to_x--;

		if(bonus->time_point_for_movement_to_y > 0)
			bonus->time_point_for_movement_to_y--; 
	}
}
@}

@d Bonus public prototypes @{@-
void bonuses_update_all_time_points(void);
@}

Напишем функцию для движения в точку.
@d Bonus functions @{
static void bonus_move_to(int bd, int x, int y) {
	BonusList *bonus = &bonuses[bd];
	
	float correction_coef;
	float now_coef;
	int fx = 0, fy = 0;
	
	if(bonus->x == x && bonus->y == y) {
		bonus->move_percent = 0;
		return;
	}

	
	if(bonus->move_percent == 0) {
		bonus->move_begin_x = bonus->x;
		bonus->move_begin_y = bonus->y;
	}

	
	{
		int dx, dy;
		float all, last;
	
		dx = bonus->move_begin_x - x;
		dy = bonus->move_begin_y - y;
		
		if(dy == 0)
			correction_coef = 100.0;
		else
			correction_coef = fabs((float)dx/(float)dy);
	
	
		all = sqrt(dx*dx + dy*dy);
	
		dx = bonus->x - x;
		dy = bonus->y - y;
		
		if(dy == 0)
			now_coef = 100.0;
		else
			now_coef = fabs((float)dx/(float)dy);
	
	
		last = sqrt(dx*dx + dy*dy);
	
		bonus->move_percent = (int)((last/all) * 100.0);
	}

	
	if(now_coef < correction_coef)
		fy = 1;
	else if(now_coef > correction_coef)
		fx = 1;
	else {
		fx = 1;
		fy = 1;
	}
	
	if(fx == 1 && bonus->x != x) {
		if(bonus->x > x)
			bonus_move_to_direction(bd, bonus_move_to_left);
		else
			bonus_move_to_direction(bd, bonus_move_to_right);
	}
	
	if(fy == 1 && bonus->y != y) {
		if(bonus->y > y)
			bonus_move_to_direction(bd, bonus_move_to_up);
		else
			bonus_move_to_direction(bd, bonus_move_to_down);
	}


}
@}
Алгоритм скопирован из уже реализованного алгоритма для character.

@d Bonus private prototypes @{@-
static void bonus_move_to(int bd, int x, int y);
@}

@d Bonuses params @{
int move_begin_x;
int move_begin_y;
@}
Эти параметры тоже из character, они хранят точку начала движения,
по ним находят move_percent.

На его основе сделаем алгоритм движения в точку с замедлением.
@d Bonus functions @{
static void bonus_move_to_slower(int bd, int x, int y) {
	bonus_move_to(bd, x, y);
	bonuses[bd].speed = bonuses[bd].move_percent;
}
@}

@d Bonus private prototypes @{@-
static void bonus_move_to_slower(int bd, int x, int y);
@}


@d Bonus functions @{
static void bonus_move_to_direction(int bd, int move_to) {
	BonusList *bonus = &bonuses[bd];

	if(bonus->time_point_for_movement_to_x == 0) {
		if(move_to == bonus_move_to_left) {
			bonus_set_weak_time_point_x(bd);
			bonus->x--;
		}
		else if(move_to == bonus_move_to_right) {
			bonus_set_weak_time_point_x(bd);
			bonus->x++;
		}
	}

	if(bonus->time_point_for_movement_to_y == 0) {
		if(move_to == bonus_move_to_up) {
			bonus_set_weak_time_point_y(bd);
			bonus->y--;
		}
		else if(move_to == bonus_move_to_down) {
			bonus_set_weak_time_point_y(bd);
			bonus->y++;
		}
	}
}
@}

@d Bonus private prototypes @{@-
static void bonus_move_to_direction(int bd, int move_to);
@}

@d Bonus private structs @{
enum {
	bonus_move_to_left, bonus_move_to_right, bonus_move_to_up, bonus_move_to_down
};
@}


@d Bonus public prototypes @{@-
void bonuses_draw(void);
@}

@d Bonus functions @{
@<Concrete functions for bonuses drawing@>
void bonuses_draw(void) {
	int i;

	for(i = 0; i < BONUS_LIST_LEN; i++) {
		BonusList *bonus = &bonuses[i];

		@<Skip cycle if bonus slot empty@>

		switch(bonus->type) {
			case bonus_small_score:
				bonus_small_score_draw(i);
				break;
			case bonus_medium_score:
				bonus_medium_score_draw(i);
				break;
			case bonus_power:
				bonus_power_draw(i);
				break;
			@<bonuses_draw other bonuses@>
			default:
				fprintf(stderr, "\nUnknown bonus\n");
				exit(1);
		}
	}
}
@}

@d Concrete functions for bonuses drawing @{
static void bonus_small_score_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bonus_small_score.png");

	image_draw_center(id,
		GAME_FIELD_X + bonuses[bd].x,
		GAME_FIELD_Y + bonuses[bd].y,
		0, 0.3);
}

static void bonus_medium_score_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bonus_medium_score.png");

	image_draw_center(id,
		GAME_FIELD_X + bonuses[bd].x,
		GAME_FIELD_Y + bonuses[bd].y,
		0, 0.3);
}

static void bonus_power_draw(int bd) {
	static int id = -1;

	if(id == -1)
		id = image_load("bonus_power.png");

	image_draw_center(id,
		GAME_FIELD_X + bonuses[bd].x,
		GAME_FIELD_Y + bonuses[bd].y,
		0, 0.5);
}
@}

Эту функцию вызывают в цикле для сброра бонусов:
@d Bonus public prototypes @{@-
void get_bonuses(void);
@}

@d Bonus functions @{
void get_bonuses(void) {
	int i;

	for(i = 0; i < BONUS_LIST_LEN; i++) {
		BonusList *bonus = &bonuses[i];

		if(bonus->is_noempty == 0)
			continue;

		switch(bonus->type) {
			@<get_bonuses all other bonuses' gets@>
			default:
				fprintf(stderr, "\nUnknown bonus\n");
				exit(1);
		}
	}
}
@}

Теперь напишем функцию которая будет вызваться когда необходимо
собрать все видимые бонусы:
@d Bonus public prototypes @{@-
void get_visible_bonuses(void);
@}

@d Bonus functions @{
void get_visible_bonuses(void) {
	int i;

	for(i = 0; i < BONUS_LIST_LEN; i++) {
		BonusList *bonus = &bonuses[i];

		if(bonus->is_noempty == 0)
			continue;

		if(bonus->x < 0 || bonus->y < 0 ||
			bonus->x > GAME_FIELD_W || bonus->y > GAME_FIELD_H)
			continue;

		switch(bonus->type) {
			@<get_visible_bonuses all other bonuses' gets@>
			default:
				fprintf(stderr, "\nUnknown bonus\n");
				exit(1);
		}
	}
}
@}

Функция сбора бонусов при достижении линии:
@d Bonus public prototypes @{@-
void move_visible_bonuses(void);
@}
Устанавливает видимым бонусам флаг движения:
@d Bonus functions @{
void move_visible_bonuses(void) {
	int i;

	for(i = 0; i < BONUS_LIST_LEN; i++) {
		BonusList *bonus = &bonuses[i];

		if(bonus->is_noempty == 0)
			continue;

		if(bonus->x < 0 || bonus->y < 0 ||
			bonus->x > GAME_FIELD_W || bonus->y > GAME_FIELD_H)
			continue;

		switch(bonus->type) {
			@<move_visible_bonuses all other bonuses' gets@>
			default:
				fprintf(stderr, "\nUnknown bonus\n");
				exit(1);
		}
	}
}
@}

@d Bonuses params @{@-
int move_to_player;
@}
Флаг нужно обнулять в конструкторе и обрабатывать в функции движения(i.e.:bonuses_action),
когда move_to_player установлен, то move_step начинает использоваться особым образом, об этом
ниже. Поэтому следует обнулять move_step при установке move_to_player.

Реализация для бонуса дающего очки:
@d get_bonuses all other bonuses' gets @{@-
case bonus_small_score:
case bonus_medium_score:
	if(is_rad_collide(player_x, player_y, player_get_radius,
			bonus->x, bonus->y, 5) == 0)
		break;
	bonus->is_noempty = 0;
	break;
@}

@d get_visible_bonuses all other bonuses' gets @{@-
case bonus_small_score:
case bonus_medium_score:
	bonus->is_noempty = 0;
	break;
@}

@d move_visible_bonuses all other bonuses' gets @{
case bonus_small_score:
case bonus_medium_score:
	if(bonus->move_to_player == 1)
		return;
	bonus->move_to_player = 1;
	bonus->move_step = 0;
	break;
@}

Реализация для бонуса дающего power:
@d get_bonuses all other bonuses' gets @{@-
case bonus_power:
	if(is_rad_collide(player_x, player_y, player_get_radius,
			bonus->x, bonus->y, 5) == 0)
		break;
	bonus->is_noempty = 0;
	player_powers++;
	break;
@}

@d get_visible_bonuses all other bonuses' gets @{@-
case bonus_power:
	bonus->is_noempty = 0;
	player_powers++;
	break;
@}

@d move_visible_bonuses all other bonuses' gets @{
case bonus_power:
	if(bonus->move_to_player == 1)
		return;
	bonus->move_to_player = 1;
	bonus->move_step = 0;
	break;
@}

Добавим в функцию bonus_small_score_action реакцию на установленный флаг move_to_player:
@d bonus_small_score_action move to player @{@-
if(bonus->move_to_player == 1) {
	if(bonus->move_step == 500)
		bonus->move_step = 0;
	if(bonus->move_step == 0) {
		bonus->speed = 0;
		bonus->move_percent = 0;
		bonus->move_x = player_x;
		bonus->move_y = player_y;
	}

	bonus_move_to(bd, bonus->move_x, bonus->move_y);

	bonus->move_step++;
	return;
}
@}
Мы используем move_step как счётчик, когда он достигает 500 мы направляем бонус в новую
позицию игрока. Такие сложности нужны потому что из-за особенностей реализации алгоритма
движения по линии, движения персонажа будут грубы из-за постоянной смены конечной точки.


=========================================================

Вывод текста в заданный бокс

1) У нас должна быть функция для задания текста который будет выводится
в бокс.
2) Должна быть функция создающая бокс с нужными координатами, размером,
типом шрифта(лучше всего задавать по-имени), свойствами вывода(сразу или
побуквенно или другие). Возвращает дескириптор.
3) Функция рисования бокса.

Верхнее решение слишком сложное. Сделаем функции которые сразу рисуют текст
в боксе нужным шрифтом. Бокс задаётся шириной и начальными координатами.
То есть выводит не весь текст, а только одну строку.
Есть функция, которая рисует столько символов, сколько влезет.
Есть функция возвращает число - позицию первой буквы(не пробела)
  слова, которое не вошло. Возможно стоит ввести комбинацию на неразрывный пробел. Сама функция не рисует.
Придётся где-то хранить дескриптор шрифта, искать в массиве каждый раз долго :(

Например мы делаем диалог персонажей:
Как выводит текст посимвольно? Надо в главный цикл вставить функцию, которая побуквенно
(каждый цикл добавляя букву) будет выводить строку не забывая проверять войдёт слово или нет.
Пример:
 string st = "long long text"
 int pos1 = pos_last_word_of_long_string(st, 120, "font1")
 print(st[:pos1], 0, 0, 120, "font1"))

 int pos2 = pos_last_word_of_long_string(st[pos:], 120, "font1")
 print(st[pos1:pos2], 0, 20, 120, "font1"))
 итд
Так мы выведем несколько строк текста.

Файл шрифта задаётся так:
В-первой строке название файла с изображением, такое, чтобы загрузить image_load.
Во-второй строке высота символа и через пробел число символов(N).
Далее N строк вида:
<символ> X Y SX

Добавим функцию с помощью которой можно рисовать часть картинки:
@d os_specific functions @{
void image_draw_corner_part(int id, int x, int y, int w, int h) {
	ImageList *img = &image_list[id];

	glLoadIdentity();

	glBindTexture(GL_TEXTURE_2D, img->tex_id);

	glTranslatef(x, y, 0);

	glBegin(GL_QUADS);
		glTexCoord2f(0, 0);
		glVertex2i(0, 0);

		glTexCoord2f((float)w/(float)img->w, 0);
		glVertex2i(w, 0);

		glTexCoord2f((float)w/(float)img->w, (float)h/(float)img->h);
		glVertex2i(w, h);


		glTexCoord2f(0, (float)h/(float)img->h);
		glVertex2i(0, h);
	glEnd();
}
@}

@d os_specific public prototypes @{
void image_draw_corner_part(int id, int x, int y, int w, int h);
@}

@o font.h @{
@<Font public prototypes@>
@}

@o font.c @{
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

#include "font.h"
#include "os_specific.h"

@<Font structs@>
@<Font private prototypes@>
@<Font functions@>
@}

Структура в которой хранится шрифт:
@d Font structs @{
#define FONT_FILE_NAME_SIZE 30

typedef struct {
	char ch;
	int x;
	int y;
	int w;
} FontChar;

typedef struct {
	char filename[FONT_FILE_NAME_SIZE];
	int img_desc;
	int h;
	int num_chars;
	FontChar *chars;
} FontList;
@}
На имя файла шрифта(без полного пути) отводится FONT_FILE_NAME_SIZE.
Один символ шрифта хранится в структуре FontChar: ch - код символа,
(x,y,w) - его позиция и ширина в текстуре.
img_desc - дескриптор текстуры.
h - высота символа.

@d Font structs @{
#define FONT_LIST_LEN 24

static FontList font_list[FONT_LIST_LEN];
static int font_list_pos;
@}
font_list_pos - указывает на позицию, где будет записан следующий загружаемый шрифт.

Скорее всего удалять chars будет операционная система, как и картинки :(


Загрузка шрифта:
@d Font public prototypes @{
int load_font(char *filename);
@}

@d Font functions @{
int load_font(char *filename) {
	char dirname[] = "fonts/";
	char buf[FONT_FILE_NAME_SIZE + sizeof(dirname) + 1];

	strcpy(buf, dirname);
	strcat(buf, filename);

	@<load_font maybe font was loaded@>
	@<load_font else load font@>
}
@}

Шрифт -- не простая картинка, поэтому может быть использован в разных
модулях. Лучше проверить грузи ли мы его. Если этот код не пригодиться,
позже удалю:
@d load_font maybe font was loaded @{@-
{
	int i;
	for(i=0; i < font_list_pos; i++)
		if(!strcmp(font_list[i].filename, filename))
			return i;
}
@}

@d load_font else load font @{@-
{
	FontList *font = &font_list[font_list_pos];
	FILE *f;

	f = fopen(buf, "r");
	if(f == NULL) {
		fprintf(stderr, "\nCann't open font file: %s\n", filename);
		exit(1);
	}

	@<load_font load image@>
	@<load_font load height and number of chars@>
	@<load_font load chars' struct@>

	fclose(f);
	return font_list_pos++;
}
@}

@d load_font load image @{@-
{
	char b[100];
	if(fgets(b, sizeof(b), f) == NULL) {
		fprintf(stderr, "\nError with reading image filename in: %s\n", filename);
		exit(1);
	}

	font->img_desc = image_load(b);
}
@}
Здесь возможен fail с именем файла > размера буфера, интересно вставит ли он \0?

@d load_font load height and number of chars @{@-
if(fscanf(f, "%d %d", &font->h, &font->num_chars) == EOF) {
	fprintf(stderr, "\nError with reading height and number of chars in: %s\n", filename);
	exit(1);
}
@}

@d load_font load chars' struct @{@-
{
	int i;

 	font->chars = malloc(sizeof(FontChar) * font->num_chars);
	if(font->chars == NULL) {
		fprintf(stderr, "\nCann't allocate %d FontChar\n", font->num_chars);
		exit(1);
	}

	for(i=0; i < font->num_chars; i++) {
		FontChar *fc = &font->chars[i];
		if(fscanf(f, "%c %d %d %d", &fc->ch, &fc->x, &fc->y, &fc->w) == EOF) {
			fprintf(stderr, "\nError with reading FontChar in: %s\n", filename);
			exit(1);
		}
	}
}
@}


=========================================================
Основной файл игры:

@o main.c @{

#include <stdlib.h>

#include "os_specific.h"
#include "event.h"
#include "collision.h"
#include "characters.h"
#include "bullets.h"
#include "timers.h"
#include "damage.h"
#include "player.h"
#include "bonuses.h"
#include "const.h"

@<Main functions@>
@}


Функция main:

@d Main functions @{

int main(void) {
	window_init();
	window_create();

	enum {
		main_character_blue_moon_fairy1,
		main_character_blue_moon_fairy10 = main_character_blue_moon_fairy1 + 9,
	};

	player_x = GAME_FIELD_W/2;
	player_y = GAME_FIELD_H - GAME_FIELD_H/8;

	player_select_team(player_team_reimu);

	{
		int i;
		for(i = main_character_blue_moon_fairy1; i <= main_character_blue_moon_fairy10; i++) {
			character_blue_moon_fairy_create(i, 30*i, 10);
			//characters[i].is_sleep = 0;
		}
		characters_pos = main_character_blue_moon_fairy10 + 1;

//		characters[main_character_blue_moon_fairy1].is_sleep = 0;
	}

/*	{
		int i, j;
		for(i=0; i<1; i++)
			for(j=0; j<2; j++)
				bullet_red_create(100+i*10, 100+j*10);
	}*/

	bonus_power_create(50, 100);

	background_set_type(background_forest);

	@<Main cycle@>
}
@}

Основной циклы игры:

@d Main cycle @{
while(1) {
	@<Update timers@>
	@<Skip frames@>
	@<FPS@>
	@<Time points@>
	@<Computer movements@>
	@<Bullet movements@>
	@<Player movements@>
	@<Bonus movements@>
	@<Player press fire button@>
	@<Damage calculate@>
	@<Get bonuses@>
	@<Game menu@>
	@<Get processor time to OS@>
}
@}

Мы держим fps~60.
FIXME: у родителей сделал 24 вместо 60, потому что тормозит.
FIXME: 60 мало, бекграунд дёргается. Надо хотя бы 80.
Добавим таймер для контроля перерисовки экрана раз в 1000/60 мс:
@d Skip frames @{
static int frames = 0;
static int main_timer_frame = 0;

main_timer_frame = timer_calc(main_timer_frame);
if(main_timer_frame == 0) {

	main_timer_frame = 1000/24;

	frames++;

	@<Draw backgrounds@>
	@<Draw bonuses@>
	@<Draw bullets@>
	@<Draw characters@>
	@<Draw player@>
	@<Draw panel@>
	@<Window update@>
}
@}
frames - необходим для подсчета FPS описаного ниже.


Пересчет очков перемещения(time point). Добавим таймер для обновления time points:
@d Time points @{
static int main_timer_time_points = 0;

main_timer_time_points = timer_calc(main_timer_time_points);
if(main_timer_time_points == 0) {

	main_timer_time_points = 1;

	characters_update_all_time_points();
	player_update_all_time_points();
	bullets_update_all_time_points();
	bonuses_update_all_time_points();
}
@}
Функции characters_update_all_time_points, player_update_all_time_points,
bullets_update_all_time_points и bonuses_update_all_time_points вызываются раз в ~1 мс.


Добавим таймер для FPS.
Считаем fps за 5 сек:
@d FPS @{
{
	static int main_timer_fps = 0;
	
	main_timer_fps = timer_calc(main_timer_fps);
	if(main_timer_fps == 0) {

		main_timer_fps = 5000;

		printf("%d frames  %d FPS\n", frames, frames/5);

		frames = 0;
	}
}
@}

Рисуем задник:
@d Draw backgrounds @{@-
background_draw();
@}

Отрисовка всех персонажей:
@d Draw characters @{@-
characters_draw();
@}

Отрисовка главного персонажа:
@d Draw player @{@-
player_draw();
@}

Отрисовка пуль:
@d Draw bullets @{@-
bullets_draw();
@}

Отрисовка бонусов:
@d Draw bonuses @{@-
bonuses_draw();
@}

Обновление экрана:
@d Window update @{
window_update();
@}

Игровое меню(оно вызывается из игры при нажатии ESC):
@d Game menu @{
if(is_keydown(key_escape)) {
	window_set_fullscreen(0);
	exit(1);
}
@}
FIXME:Пока вместо меню заглушка




Перемещение персонажа игроком:
@d Player movements @{
if(is_keydown(key_move_left))
	player_move_to(player_move_to_left);
else if(is_keydown(key_move_right))
	player_move_to(player_move_to_right);

if(is_keydown(key_move_up))
	player_move_to(player_move_to_up);
else if(is_keydown(key_move_down))
	player_move_to(player_move_to_down);
@}
Кнопки влево, вправо и вверх, вниз разделены, чтобы была возможность перемещаться по диагонали.

Игрок нажал кнопку "огонь":
@d Player press fire button @{
if(is_keydown(key_fire))
	player_fire();
@}

Перемещение персонажей управляемых компьютером:
@d Computer movements @{
characters_ai_control();
@}

Перемещение пуль:
@d Bullet movements @{
bullets_action();
@}

Перемещение бонусов:
@d Bonus movements @{
bonuses_action();
@}

Обновим таймеры:
@d Update timers @{
timer_get_time();
@}

Подсчитаем повреждения от пуль:
@d Damage calculate @{
damage_calculate();
@}

Собираем бонусы:
@d Get bonuses @{
get_bonuses();
player_bonus_line();
@}
get_bonuses - собираем сами бонусы;
player_bonus_line - проверяем бонусную линию.

Отдадим процессору немного времени:
@d Get processor time to OS @{
get_processor_time();
@}
FIXME: что-то на nvidia он жутко просаживает систему
