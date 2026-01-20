import html2canvas from "html2canvas";
import jsPDF from "jspdf";

type PdfOptions = {
  filename: string;
  pageWidth?: number; // in mm
  pageHeight?: number; // in mm
  marginMm?: number;
};

/**
 * Renders a DOM element to PDF client-side. All values must already come from
 * the backend (no calculations here). Useful for “print current sheet” with
 * a pixel-like snapshot of the on-screen layout.
 */
export async function exportElementToPdf(
  element: HTMLElement,
  { filename, pageWidth = 210, pageHeight = 297, marginMm = 10 }: PdfOptions
) {
  // Render element to canvas at 2x scale for sharper text.
  const canvas = await html2canvas(element, {
    scale: 2,
    useCORS: true,
    backgroundColor: "#ffffff",
  });

  const imgData = canvas.toDataURL("image/png");

  const pdf = new jsPDF({
    orientation: pageWidth > pageHeight ? "l" : "p",
    unit: "mm",
    format: [pageWidth, pageHeight],
  });

  const imgWidth = pageWidth - marginMm * 2;
  const imgHeight =
    (canvas.height * imgWidth) / (canvas.width || imgWidth || 1);

  pdf.addImage(
    imgData,
    "PNG",
    marginMm,
    marginMm,
    imgWidth,
    Math.min(imgHeight, pageHeight - marginMm * 2)
  );

  pdf.save(filename);
}

