import std.datetime;
import std.stdio;

import diet.html;

// TODO load globals from file
// TODO support code markup (use markdown)
// TODO improve styling of post page

static immutable string SOURCEPATH = "content/";
static immutable string TARGETPATH = "build/";

struct GlobalsImpl
{
  string WebsiteName = "Barely Laughing";
}

immutable GlobalsImpl GLOBALS = GlobalsImpl();

struct Page(T) {
  T obj;
  string url;
}

mixin template Register(T)
{
  static Page!(T)[] objs;
  static int parse_count;
}

struct Index
{
  string heading;
  Page!(Post)[] posts;
  Link[] links;
  Bird[] birds;
  Song[] songs;

  static Index parse(string path)
  in (Post.parse_count > 0)
  {
    import std.algorithm : map, sort;
    import std.array : array;
    import std.file : readText;
    import std.string : splitLines;

    return Index(
      "b5.re",
      // posts
      Post.objs.sort!("a.obj.modified > b.obj.modified").array,
      // cool links
      from_csv!Link(make_basepath("links.csv")),
      // bird log
      make_basepath("birds.txt").readText.splitLines.map!(Bird).array,
      // cool songs
      from_csv!Song(make_basepath("songs.csv")),
    );
  }
}

struct Post
{
  string title;
  string[] content;
  DateTime modified;

  mixin Register!Post;

  string formatted_date()
  {
    import std.format : format;

    // probably a better way to do this
    return "%d/%02d/%02d".format(
      modified.year, modified.month, modified.day,
    );
  }

  static Post parse(string path)
  out (; Post.parse_count > 0)
  {
    import std.file : readText, timeLastModified;
    import std.string : splitLines;

    DateTime modified = cast(DateTime) path.timeLastModified;
    string[] parts = readText(path).splitLines;
    Post.parse_count += 1;
    return Post(parts[0], parts[1 .. $], modified);
  }
}

T[] from_csv(T)(string path)
{
  import std.array : array;
  import std.csv : csvReader;
  import std.file : readText;

  return path.readText.csvReader!T(',').array;
}

struct Link
{
  string title;
  string url;
  string added; // string representation of a date
}

struct Song
{
  string name;
  string artist;
  string url;
}

struct Bird
{
  string name;
}

string[] get_posts(string basepath)
{
  import std.array : array;
  import std.algorithm : map, uniq;
  import std.conv : to;
  import std.file : dirEntries, SpanMode;

  auto entries = basepath.dirEntries(SpanMode.breadth).map!(to!string).uniq.array;

  if (entries.length == 0) {
    // special case when there are no posts
    Post.parse_count = 1;
  }

  return entries;
}

string make_basepath(string suffix)
{
  import std.path : buildPath;
  return buildPath(SOURCEPATH, suffix);
}

void write_file(T, string TemplateFile)(string src_path)
{
  import std.array : replace;
  import std.file : exists, mkdirRecurse, readText;
  import std.path : buildPath, dirName, setExtension;

  string path = buildPath(TARGETPATH, src_path).replace(SOURCEPATH, "").setExtension("html");
  string dirs = path.dirName;

  if (!dirs.exists) {
    mkdirRecurse(dirs);
  }

  auto file = File(path, "wt");
  auto dest = file.lockingTextWriter;
  T ctx = T.parse(src_path);
  dest.compileHTMLDietFile!(TemplateFile, ctx, GLOBALS);

  static if (__traits(hasMember, T, "objs")) {
    // register this page instance so it can be referenced elsewhere
    T.objs ~= Page!T(ctx, path.replace(TARGETPATH, ""));
  }
}

void write_static()
{
  import std.file : copy, dirEntries, exists, mkdirRecurse, SpanMode;
  import std.path : baseName, buildPath, dirName;

  string src_css_path = buildPath(SOURCEPATH, "css", "main.css");
  if (src_css_path.exists) {
    string target_css_path = buildPath(TARGETPATH, "css", "main.css");
    mkdirRecurse(dirName(target_css_path));
    copy(src_css_path, target_css_path);
  }

  string src_img_path = buildPath(SOURCEPATH, "images");
  if (src_img_path.exists) {
    string target_img_path = buildPath(TARGETPATH, "images");
    mkdirRecurse(target_img_path);
    foreach (img; src_img_path.dirEntries(SpanMode.breadth)) {
      copy(img, buildPath(target_img_path, baseName(img)));
    }
  }
}

void main(string[] args)
{
  import std.file : exists, mkdir;

  // Sources for site go in content/
  // Output from build goes in build/
  // views/ is for diet templates

  if (!TARGETPATH.exists) {
    TARGETPATH.mkdir;
  }

  foreach (post; get_posts(make_basepath("posts/"))) {
    write_file!(Post, "post.dt")(post);
  }

  write_file!(Index, "index.dt")(make_basepath("index.txt"));
  write_static();
}
