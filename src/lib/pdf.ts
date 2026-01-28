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
  // Add temporary class for PDF rendering
  element.classList.add('pdf-rendering');
  
  // Render element to canvas at 2x scale for sharper text.
  const canvas = await html2canvas(element, {
    scale: 2,
    useCORS: true,
    backgroundColor: "#ffffff",
    logging: false,
    windowWidth: element.scrollWidth,
    windowHeight: element.scrollHeight,
    scrollY: -window.scrollY,
    scrollX: -window.scrollX,
  });
  
  // Remove temporary class
  element.classList.remove('pdf-rendering');

  const imgData = canvas.toDataURL("image/png");

  const pdf = new jsPDF({
    orientation: pageWidth > pageHeight ? "l" : "p",
    unit: "mm",
    format: [pageWidth, pageHeight],
  });

  const imgWidth = pageWidth - marginMm * 2;
  const imgHeight = (canvas.height * imgWidth) / canvas.width;
  const pageContentHeight = pageHeight - marginMm * 2;

  // If content fits on one page, add it directly
  if (imgHeight <= pageContentHeight) {
    pdf.addImage(imgData, "PNG", marginMm, marginMm, imgWidth, imgHeight);
  } else {
    // Multi-page: split content across pages
    let remainingHeight = imgHeight;
    let yPosition = 0;
    let pageNumber = 0;

    while (remainingHeight > 0) {
      if (pageNumber > 0) {
        pdf.addPage();
      }

      const heightForThisPage = Math.min(remainingHeight, pageContentHeight);
      
      // Calculate source position in the canvas
      const sourceY = (yPosition * canvas.height) / imgHeight;
      const sourceHeight = (heightForThisPage * canvas.height) / imgHeight;

      // Create a temporary canvas for this page slice
      const pageCanvas = document.createElement('canvas');
      pageCanvas.width = canvas.width;
      pageCanvas.height = sourceHeight;
      const pageCtx = pageCanvas.getContext('2d');
      
      if (pageCtx) {
        pageCtx.drawImage(
          canvas,
          0, sourceY, canvas.width, sourceHeight,
          0, 0, canvas.width, sourceHeight
        );
        
        const pageImgData = pageCanvas.toDataURL("image/png");
        pdf.addImage(pageImgData, "PNG", marginMm, marginMm, imgWidth, heightForThisPage);
      }

      remainingHeight -= pageContentHeight;
      yPosition += pageContentHeight;
      pageNumber++;
    }
  }

  pdf.save(filename);
}

