using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Text;
using System.Text.RegularExpressions;
using System.Runtime.InteropServices;
using System.ComponentModel;

namespace PdfiumSharp{
  public class PdfInformation {
    public string Author { get; set; }
    public string Creator { get; set; }
    public DateTime? CreationDate { get; set; }
    public string Keywords { get; set; }
    public DateTime? ModificationDate { get; set; }
    public string Producer { get; set; }
    public string Subject { get; set; }
    public string Title { get; set; }
  }

  public class Native {

    [Flags]
    public enum FPDF {
      ANNOT = 0x01,
      LCD_TEXT = 0x02,
      NO_NATIVETEXT = 0x04,
      GRAYSCALE = 0x08,
      DEBUG_INFO = 0x80,
      NO_CATCH = 0x100,
      RENDER_LIMITEDIMAGECACHE = 0x200,
      RENDER_FORCEHALFTONE = 0x400,
      PRINTING = 0x800,
      REVERSE_BYTE_ORDER = 0x10
    }

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern void FPDF_InitLibrary();

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern void FPDF_DestroyLibrary();

    [DllImport("pdfium.dll", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr FPDF_LoadDocument([MarshalAs(UnmanagedType.LPStr)] string filepath, [MarshalAs(UnmanagedType.LPStr)] string password);

    [DllImport("pdfium.dll", CharSet = CharSet.Ansi, CallingConvention = CallingConvention.StdCall)]
    public static extern int FPDF_GetPageCount(IntPtr document);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern uint FPDF_GetMetaText(IntPtr document, string tag, byte[] buffer, uint buflen);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr FPDFBitmap_CreateEx(int width, int height, int format, IntPtr first_scan, int stride);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern void FPDFBitmap_FillRect(IntPtr bitmapHandle, int left, int top, int width, int height, uint color);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr FPDFBitmap_Destroy(IntPtr bitmapHandle);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern void FPDF_RenderPageBitmap(IntPtr bitmapHandle, IntPtr page, int start_x, int start_y, int size_x, int size_y, int rotate, FPDF flags);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr FPDF_LoadPage(IntPtr document, int page_index);

    [DllImport("pdfium.dll", CallingConvention = CallingConvention.StdCall)]
    public static extern IntPtr FPDFText_LoadPage(IntPtr page);

    public static string GetMetaText(IntPtr _document, string _tag) {
      // Length includes a trailing \0.
      uint length = FPDF_GetMetaText(_document, _tag, null, 0);
      //Console.WriteLine("\nlenght: " + length);
      if (length <= 2)
        return string.Empty;

      byte[] buffer = new byte[length];
      FPDF_GetMetaText(_document, _tag, buffer, length);

      return Encoding.Unicode.GetString(buffer, 0, (int)(length - 2));
    }
    public static DateTime? GetMetaTextAsDate(IntPtr _document, string _tag) {
      string dt = Native.GetMetaText(_document, _tag);

      if (string.IsNullOrEmpty(dt))
        return null;

      Regex dtRegex =
          new Regex(
              @"(?:D:)(?<year>\d\d\d\d)(?<month>\d\d)(?<day>\d\d)(?<hour>\d\d)(?<minute>\d\d)(?<second>\d\d)(?<tz_offset>[+-zZ])?(?<tz_hour>\d\d)?'?(?<tz_minute>\d\d)?'?");

      Match match = dtRegex.Match(dt);

      if (match.Success) {
        var year = match.Groups["year"].Value;
        var month = match.Groups["month"].Value;
        var day = match.Groups["day"].Value;
        var hour = match.Groups["hour"].Value;
        var minute = match.Groups["minute"].Value;
        var second = match.Groups["second"].Value;
        var tzOffset = match.Groups["tz_offset"]?.Value;
        var tzHour = match.Groups["tz_hour"]?.Value;
        var tzMinute = match.Groups["tz_minute"]?.Value;

        string formattedDate = $"{year}-{month}-{day}T{hour}:{minute}:{second}.0000000";

        if (!string.IsNullOrEmpty(tzOffset)) {
          switch (tzOffset) {
            case "Z":
            case "z":
              formattedDate += "+0";
              break;
            case "+":
            case "-":
              formattedDate += $"{tzOffset}{tzHour}:{tzMinute}";
              break;
          }
        }

        try {
          return DateTime.Parse(formattedDate);
        }
        catch (FormatException) {
          return null;
        }
      }

      return null;
    }
  }

  public class PageData : IDisposable {
    public IntPtr Page { get; private set; }
    public IntPtr TextPage { get; private set; }

    private bool _disposed;

    public PageData(IntPtr _document, int pageNumber) {

      Page = Native.FPDF_LoadPage(_document, pageNumber);
      TextPage = Native.FPDFText_LoadPage(Page);

    }

    public void Dispose() {
      if (!_disposed) {


        _disposed = true;
      }
    }

  }

  public class PDF {

    public string file;
    public IntPtr doc;
    public PDF() {
      // Native call return void argument...
      Native.FPDF_InitLibrary();

    }

    ~PDF() {
      Native.FPDF_DestroyLibrary();
    }


    public bool Load(string F) {

      file = F;

      doc = Native.FPDF_LoadDocument(file, null);

      if (doc != null) return true;
      else return false;

    }

    public int PageCount() {

      return Native.FPDF_GetPageCount(doc);

    }
    public PdfInformation GetInformation() {
      var pdfInfo = new PdfInformation();

      pdfInfo.Creator = Native.GetMetaText(doc, "Creator");
      pdfInfo.Title = Native.GetMetaText(doc, "Title");
      pdfInfo.Author = Native.GetMetaText(doc, "Author");
      pdfInfo.Subject = Native.GetMetaText(doc, "Subject");
      pdfInfo.Keywords = Native.GetMetaText(doc, "Keywords");
      pdfInfo.Producer = Native.GetMetaText(doc, "Producer");
      pdfInfo.CreationDate = Native.GetMetaTextAsDate(doc, "CreationDate");
      pdfInfo.ModificationDate = Native.GetMetaTextAsDate(doc, "ModDate");

      return pdfInfo;
    }

    // For Rendering
    public bool RenderPDFPageToBitmap(int pageNumber, IntPtr bitmapHandle, int dpiX, int dpiY,
                                             int boundsOriginX, int boundsOriginY, int boundsWidth, int boundsHeight,
                                             int rotate, Native.FPDF flags, bool renderFormFill) {
      //if (_disposed)
      //  throw new ObjectDisposedException(GetType().Name);

      using (var pageData = new PageData(doc, pageNumber)) {
        // if (renderFormFill)
        //   flags &= ~NativeMethods.FPDF.ANNOT;

        //Native.FPDF_RenderPageBitmap(bitmapHandle, pageData.Page, boundsOriginX, boundsOriginY, 
        //                            boundsWidth, boundsHeight, rotate, flags);
        Native.FPDF_RenderPageBitmap(bitmapHandle, pageData.Page, boundsOriginX, boundsOriginY,
                                    boundsWidth, boundsHeight, 0, flags);
        //if (renderFormFill)
        // NativeMethods.FPDF_FFLDraw(_form, bitmapHandle, pageData.Page, boundsOriginX, boundsOriginY, boundsWidth, boundsHeight, rotate, flags);
      }

      return true;
    }

    public Image Render(int page, int width, int height, float dpiX, float dpiY) {
      //PdfRotation rotate, PdfRenderFlags flags){

      //if (_disposed)
      //   throw new ObjectDisposedException(GetType().Name);

      //if ((flags & PdfRenderFlags.CorrectFromDpi) != 0){
      //width = width* (int) dpiX / 72;
      //height = height* (int) dpiY / 72;
      //}

      var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb);
      bitmap.SetResolution(dpiX, dpiY);

      var data = bitmap.LockBits(new Rectangle(0, 0, width, height), ImageLockMode.ReadWrite, bitmap.PixelFormat);

      try {
        var handle = Native.FPDFBitmap_CreateEx(width, height, 4, data.Scan0, width * 4);

        try {
          //uint background = (flags & PdfRenderFlags.Transparent) == 0 ? 0xFFFFFFFF : 0x00FFFFFF;
          uint background = 0xFFFFFFFF;
          Native.FPDFBitmap_FillRect(handle, 0, 0, width, height, background);

          bool success = this.RenderPDFPageToBitmap(
              page,
              handle,
              (int)dpiX, (int)dpiY,
              0, 0, width, height,
              0,
              0, //FlagsToFPDFFlags(flags),
              false //(flags & PdfRenderFlags.Annotations) != 0
          );

          if (!success)
            throw new Win32Exception();
        }
        finally {
          Native.FPDFBitmap_Destroy(handle);
        }
      }
      finally {
        bitmap.UnlockBits(data);
      }

      return bitmap;

    }

  }

}
