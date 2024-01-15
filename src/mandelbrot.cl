__kernel void mandelbrot(__global int *screen, const ulong width,
                         const ulong height, const double scale,
                         const double2 origin,
                         const ulong max_iteration_count) {
  int2 p = (int2)(get_global_id(0), get_global_id(1));

  double halfwidth = (width - 1.0) * 0.5;
  double halfheight = (height - 1.0) * 0.5;

  double2 z0 = (double2)((p.x - halfwidth) / scale - origin.x,
                         (halfheight - p.y) / scale - origin.y);

  ulong iteration_count = 0;

  double2 z = (double2)(0.0, 0.0);

  while (z.x * z.x + z.y * z.y <= 2 * 2 &&
         iteration_count < max_iteration_count) {
    double zxtemp = z.x * z.x - z.y * z.y + z0.x;
    z.y = 2.0 * z.x * z.y + z0.y;
    z.x = zxtemp;

    iteration_count++;
  }

  double colort =
      min(((double)iteration_count) / max_iteration_count, 1.0) * 0xff;

  unsigned char r = colort;
  unsigned char g = colort;
  unsigned char b = colort;

  screen[p.x + p.y * width] = r << 8 * 3 | g << 8 * 2 | b << 8 | 0xff;
}
