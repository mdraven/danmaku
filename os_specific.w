
===========================================================

Набор функция для работы с окном(создание, рисование...).

Структура файла функций зависимых от ОС:
@o os_specific.c @{
@<License@>

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
@<License@>

@<os_specific public structs@>
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
static void window_set_2d_config(void) {
    //glClearColor(0, 0, 0, 0);
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

@d os_specific private prototypes @{
static void window_set_2d_config(void);
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

Так как нам придётся проверять все рисунки, то мы будем их хранить в массиве.
Для начала, почему массив? Этот массив похож на стек. Список рисунков всё равно не
имеет дыр, поэтому будем использовать этот достаточно простой вариант.
id который возвращает image_load и есть номер элемента в массиве.

Опишем структуру в которой будет храниться список открытых изображений:
@d os_specific structs @{
#define IMAGE_LIST_LEN 128
#define IMG_FILE_NAME_SIZE 256

typedef struct {
    char filename[IMG_FILE_NAME_SIZE];
    int w, h;
    unsigned int tex_id;
    int ref;
} ImageList;

static ImageList image_list[IMAGE_LIST_LEN];
static int image_list_pos;
@}
Это стек, image_list_pos его вершина.
IMG_FILE_NAME_SIZE длинна массива под имя файла включая и путь к файлу.
IMAGE_LIST_LEN количество изображений или иными словами размер стека.
ref - число ссылок

filename - имя файла с картинкой
w, h - размеры картинки
tex_id - дескриптор текстуры в opengl


@d os_specific functions @{
static int find_image(char *abs_filename) {
    int i;
    for(i = 0; i < image_list_pos; i++)
        if(strcmp(abs_filename, image_list[i].filename) == 0)
            return i;

    return -1;
}
@}

@d os_specific functions @{
static int add_image(char *abs_filename) {
   if(image_list_pos == IMAGE_LIST_LEN) {
        fprintf(stderr, "\nImage list full\n");
        exit(1);
    }

    strncpy(image_list[image_list_pos].filename, abs_filename,
            sizeof(image_list[image_list_pos].filename) - 1);

    image_list[image_list_pos].ref = 1;

    {
        int bytes_per_pixel;
        int texture_format;

        ImageList *image = &image_list[image_list_pos];

        SDL_Surface *img = load_from_file(abs_filename);

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
  strncpy(как и прочие strnXXX функции) -- дурацкая функция и ей надо передавать
    размер_буфера - 1. Другим strnXXX нужно передавать и похуже вещи.
То есть в структуре-стеке всегда валидное имя.
Используется вспомогательная функция load_from_file, она загружает картинку по заданому пути.
Функция image_load возвращает позицию в стеке, она служит дескриптором изображения.


Размер должен быть кратен 2:
@d os_specific image file size check @{
if((img->w & (img->w - 1)) != 0 ||
    (img->h & (img->h - 1)) != 0) {
    fprintf(stderr, "\nImage size isn't power of 2: %s\n", abs_filename);
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
        fprintf(stderr, "\nIncorect color type: %s\n", abs_filename);
        exit(1);
}
@}
Допустимо только 4 или 3 байта на пиксел.



Теперь о вспомогательной функции подробнее:
@d os_specific functions @{
static SDL_Surface *load_from_file(char *filename) {
    SDL_Surface *img;

    img = IMG_Load(filename);
    if(img == 0) {
        fprintf(stderr, "IMG_Load: %s\n", IMG_GetError());
        exit(1);
    }

    return img;
}
@}
У функция подсчитывает количество символов в имени директории и создаёт подходящий массив.
Она не проверяет есть ли '.' в пути к файлу, это потенциальная уязвимость, но пока это меня
не беспокоит :3

@d os_specific private prototypes @{
static SDL_Surface *load_from_file(char *filename);
@}


Функция загрузки изображения image_load:
@d os_specific functions @{
int image_load(char *filename) {
    int ret;

    char *t = realpath(filename, NULL);
    if(t == NULL) {
        fprintf(stderr, "Incorrect path for image file: %s\n", filename);
        exit(1);
    }

    ret = find_image(t);
    if(ret != -1) {
        image_list[ret].ref++;
        goto end;
    }

    ret = add_image(t);
end:
    free(t);

    return ret;
}
@}

@d os_specific public prototypes @{
int image_load(char *filename);
@}



Функция вывода изображения с левого-верхнего края:
@d os_specific functions @{
/*void image_draw_corner(int id, int x, int y, float rot, float scale) {
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
}*/
@}

@d os_specific public prototypes
@{//void image_draw_corner(int id, int x, int y, float rot, float scale);
@}



Функция вывода изображения с центра:
@d os_specific functions @{
void image_draw_center(int id, int x, int y, float rot, float scale) {
    ImageList *img = &image_list[id];

    image_draw_center_t(id, x, y,
        0, 0, img->w, img->h,
        rot, scale);
/*
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
*/
}

void image_draw_center_t(int id, int x, int y,
        int tx1, int ty1, int tx2, int ty2,
        float rot, float scale) {
    ImageList *img = &image_list[id];
    int w = tx2 - tx1;
    int h = ty2 - ty1;

    glLoadIdentity();

    glBindTexture(GL_TEXTURE_2D, img->tex_id);

    glTranslatef(x, y, 0);
    glRotatef(rot, 0, 0, 1);
    glScalef(scale, scale, 0);

    glBegin(GL_QUADS);
        glTexCoord2f((float)tx1/(float)img->w,
            (float)ty1/(float)img->h);
        glVertex2i(-w/2, -h/2);

        glTexCoord2f((float)tx2/(float)img->w,
            (float)ty1/(float)img->h);
        glVertex2i(w/2, -h/2);

        glTexCoord2f((float)tx2/(float)img->w,
            (float)ty2/(float)img->h);
        glVertex2i(w/2, h/2);

        glTexCoord2f((float)tx1/(float)img->w,
            (float)ty2/(float)img->h);
        glVertex2i(-w/2, h/2);
    glEnd();
}

void image_draw_center_t_mirror(int id, int x, int y,
        int tx1, int ty1, int tx2, int ty2,
        float rot, float scale) {
    ImageList *img = &image_list[id];
    int w = tx2 - tx1;
    int h = ty2 - ty1;

    glLoadIdentity();

    glBindTexture(GL_TEXTURE_2D, img->tex_id);

    glTranslatef(x, y, 0);
    glRotatef(rot, 0, 0, 1);
    glScalef(scale, scale, 0);

    glBegin(GL_QUADS);
        glTexCoord2f((float)tx1/(float)img->w,
            (float)ty1/(float)img->h);
        glVertex2i(w/2, -h/2);

        glTexCoord2f((float)tx2/(float)img->w,
            (float)ty1/(float)img->h);
        glVertex2i(-w/2, -h/2);

        glTexCoord2f((float)tx2/(float)img->w,
            (float)ty2/(float)img->h);
        glVertex2i(-w/2, h/2);

        glTexCoord2f((float)tx1/(float)img->w,
            (float)ty2/(float)img->h);
        glVertex2i(w/2, h/2);
    glEnd();
}
@}

@d os_specific public prototypes @{
void image_draw_center(int id, int x, int y, float rot, float scale);
void image_draw_center_t(int id, int x, int y, int tx1, int ty1, int tx2, int ty2, float rot, float scale);
void image_draw_center_t_mirror(int id, int x, int y, int tx1, int ty1, int tx2, int ty2, float rot, float scale);
@}

Добавим функцию с помощью которой можно рисовать часть картинки:
@d os_specific functions @{
void image_draw_corner(int id, int x, int y,
    int tx1, int ty1, int tx2, int ty2,
    float scale, int color) {

    ImageList *img = &image_list[id];
    int w = tx2 - tx1;
    int h = ty2 - ty1;

    glLoadIdentity();

    glBindTexture(GL_TEXTURE_2D, img->tex_id);

    glTranslatef(x, y, 0);
    //glRotatef(rot, 0, 0, 1);
    glScalef(scale, scale, 0);

    switch(color) {
        @<os_specific switch colors@>
        default:
            fprintf(stderr, "\nUnknown color\n");
            exit(1);
    }

    glBegin(GL_QUADS);
        glTexCoord2f((float)tx1/(float)img->w,
            (float)ty1/(float)img->h);
        glVertex2i(0, 0);

        glTexCoord2f((float)tx2/(float)img->w,
            (float)ty1/(float)img->h);
        glVertex2i(w, 0);

        glTexCoord2f((float)tx2/(float)img->w,
            (float)ty2/(float)img->h);
        glVertex2i(w, h);

        glTexCoord2f((float)tx1/(float)img->w,
            (float)ty2/(float)img->h);
        glVertex2i(0, h);
    glEnd();

    glColor3ub(255,255,255);
}
@}

@d os_specific public prototypes @{
void image_draw_corner(int id, int x, int y,
    int tx1, int ty1, int tx2, int ty2,
    float scale, int color);
@}

@d os_specific public structs @{
enum {
    color_white, color_red, color_blue, color_green
};
@}

@d os_specific switch colors
@{case color_white:
    glColor3ub(255,255,255);
    break;
case color_red:
    glColor3ub(255,155,155);
    break;
case color_green:
    glColor3ub(155,255,155);
    break;
case color_blue:
    glColor3ub(155,155,255);
    break;
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
