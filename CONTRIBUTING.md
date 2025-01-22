# Contributing
## Have a feature request or a bug to report?
Feel free to [submit an issue](https://github.com/mikael-ros/picket/issues) :)

## Want to work on such a feature or bug yourself?
You're very welcome to do so. All you need to know is basic GDScript and programming & git principles. Heres a short guide on how to get started:

1. Fork this repository
2. Install prerequisites
    - [git](https://git-scm.com/)
    - [Godot Engine](https://godotengine.org/)
    - This plugin
3. Load the demo
4. Make sure the demo works as expected before making modifications
5. When done, submit a pull request and wait for review

### Some coding principles
- Avoid heavy algorithms
- Write clean and concise code, with descriptive variables
- Keep documentation comments up to date as you go (or before pull request)
- Write documentation in simple english

### Testing procedure
At the moment, not rigorous testing or test suite is applied, but make sure the demo works as expected at the very least.

### Writing documentation
Follow similar guidelines as the Godot docs.

When generating GIFs, I apply the following process:
1. Record with [peek](https://github.com/phw/peek) or any other software that can record ``.mp4`` files (or other high frame rate / high fidelity formats) such as [Open Broadcaster Software (OBS)](https://obsproject.com/).
    > note: peek is stopping development, so you should ideally choose something else
2. Convert video files to ``.gif``. I use the following command, found on [bannerbear](https://www.bannerbear.com/blog/how-to-make-a-gif-from-a-video-using-ffmpeg/):
    ```sh
    ffmpeg -i <video_file_name> -filter_complex "[0:v] split [a][b];[a] palettegen [p];[b][p] paletteuse" <output_name>.gif
    ```
> [!TIP]
> You can adjust where in the video you want the gif sampled, example:
>
> ``-ss 1.0 -t 5`` for a snippet from t=1 to t=6.
>
> Add this right after the ``ffmpeg``, like: ``ffmpeg <time commands> <rest of command>``

> [!TIP]
> Adding onto the previous tip, you can read the duration of a video using ``ffprobe`` and then use that in conjunction with the parameters to cut off the end of a video. [This StackExchange post outlines a method to do this automatically](https://superuser.com/questions/744823/how-i-could-cut-the-last-7-seconds-of-my-video-with-ffmpeg).

> [!CAUTION]
> I barely know how to use ffmpeg, it's essentially dark arts to me. It is very possible the command above does not work as intended for every use case, it's just simply what I happened to find when searching.

> [!NOTE]
> Why the above process?:
>
> I do this to attain high quality, high frame rate gifs.