package com.theNext.personal_cognitive

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.Shader
import kotlin.math.min

/**
 * 위젯 배경 — 대형 허브·위성 관계망, M3 선명 컬러, iso 입체 투영.
 */
internal object WidgetGraphBackgroundRenderer {
  private val m3GraphColors = intArrayOf(
    0xFFE91E63.toInt(),
    0xFF00897B.toInt(),
    0xFF7E57C2.toInt(),
    0xFF673AB7.toInt(),
    0xFF42A5F5.toInt(),
    0xFFFF9800.toInt(),
    0xFFFF5722.toInt(),
    0xFF009688.toInt(),
    0xFF5C6BC0.toInt(),
    0xFFFFB300.toInt(),
  )

  private data class GraphHub(
    val nx: Float,
    val ny: Float,
    val depth: Float,
    val radiusDp: Float,
  )

  private data class GraphNode(
    val nx: Float,
    val ny: Float,
    val depth: Float,
    val radiusDp: Float,
    val tintIndex: Int,
    val isHub: Boolean = false,
  )

  private data class PointF(val x: Float, val y: Float)

  fun render(
    context: Context,
    primaryColor: Int,
    isDark: Boolean,
    widthDp: Int = 800,
    heightDp: Int = 520,
  ): Bitmap {
    val density = context.resources.displayMetrics.density
    val width = (widthDp * density).toInt().coerceAtLeast(1)
    val height = (heightDp * density).toInt().coerceAtLeast(1)
    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(bitmap)

    val palette = buildVividPalette(primaryColor, isDark)

    drawAmbientBackground(canvas, width, height, palette, isDark)
    drawDepthPlane(canvas, width, height, density, palette, isDark)

    val hub = GraphHub(0.58f, 0.44f, 0.32f, 34f)
    val hubNode = GraphNode(hub.nx, hub.ny, hub.depth, hub.radiusDp, 0, isHub = true)
    val satellites = buildOrbitalSatellites(hub, palette.size)
    val allNodes = satellites + hubNode
    val projected = allNodes.associateWith { project(it, width, height, density) }
    val hubPt = project(hub, width, height, density)
    val hubRadiusPx = hub.radiusDp * density

    drawHubAura(canvas, hubPt.x, hubPt.y, hubRadiusPx, palette, isDark)
    drawOrbitalGuides(canvas, hubPt, hubRadiusPx, palette, isDark)

    val edges = buildEdges(satellites, hubNode)
    val sortedEdges = edges.sortedBy { (from, to, _) -> min(from.depth, to.depth) }
    for ((from, to, strength) in sortedEdges) {
      val a = projected[from] ?: continue
      val b = projected[to] ?: continue
      val depth = min(from.depth, to.depth)
      val tintA = palette[from.tintIndex % palette.size]
      val tintB = palette[to.tintIndex % palette.size]
      val stroke = (2.0f + (1f - depth) * 3.2f + strength * 0.8f) * density
      val alpha = if (isDark) 0.38f + (1f - depth) * 0.38f else 0.28f + (1f - depth) * 0.28f
      drawArcEdge(canvas, a, b, tintA, tintB, stroke, alpha + strength * 0.08f, isDark)
    }

    for (node in allNodes.sortedBy { it.depth }) {
      val pt = projected[node]!!
      val scale = 0.86f + (1f - node.depth) * 0.58f
      val r = node.radiusDp * density * scale
      val shadowDy = (node.depth * 11f + 4f) * density
      val shadowAlpha = if (isDark) 0.36f + (1f - node.depth) * 0.22f else 0.18f + (1f - node.depth) * 0.14f
      drawNodeShadow(canvas, pt.x, pt.y + shadowDy, r * 1.35f, shadowAlpha, isDark)
      if (!node.isHub) {
        drawSatelliteGlow(canvas, pt.x, pt.y, r, palette[node.tintIndex % palette.size], isDark)
      }
      drawSphereNode(
        canvas,
        pt.x,
        pt.y,
        r,
        palette[node.tintIndex % palette.size],
        node.depth,
        isDark,
        node.isHub,
      )
    }

    drawSoftVignette(canvas, width, height, isDark)
    return bitmap
  }

  private fun buildVividPalette(primaryColor: Int, isDark: Boolean): IntArray {
    val colors = IntArray(1 + m3GraphColors.size)
    colors[0] = tuneVividColor(primaryColor, isDark, isHub = true)
    for (i in m3GraphColors.indices) {
      colors[i + 1] = tuneVividColor(m3GraphColors[i], isDark, isHub = false)
    }
    return colors
  }

  private fun tuneVividColor(color: Int, isDark: Boolean, isHub: Boolean): Int {
    val hsv = FloatArray(3)
    Color.colorToHSV(color, hsv)
    hsv[1] = min(1f, hsv[1] * (if (isDark) 1.02f else 1.08f) + (if (isHub) 0.06f else 0.04f))
    hsv[2] = min(1f, hsv[2] * (if (isDark) 1.14f else 1.02f))
    return Color.HSVToColor(Color.alpha(color), hsv)
  }

  private fun buildOrbitalSatellites(hub: GraphHub, paletteSize: Int): List<GraphNode> {
    val specs = listOf(
      OrbitSpec(0.00f, 0.94f, 0.58f, 15.5f, 1),
      OrbitSpec(0.45f, 0.90f, 0.50f, 14.5f, 2),
      OrbitSpec(0.90f, 0.62f, 0.44f, 13.5f, 3),
      OrbitSpec(0.98f, 0.16f, 0.52f, 12.8f, 4),
      OrbitSpec(0.70f, 0.02f, 0.64f, 12.0f, 5),
      OrbitSpec(0.22f, 0.04f, 0.70f, 11.2f, 6),
      OrbitSpec(0.02f, 0.36f, 0.76f, 10.5f, 7),
      OrbitSpec(0.08f, 0.72f, 0.82f, 9.8f, 8),
      OrbitSpec(0.40f, 0.98f, 0.86f, 9.2f, 9),
      OrbitSpec(0.84f, 0.84f, 0.74f, 11.8f, 10),
      OrbitSpec(0.96f, 0.44f, 0.88f, 8.6f, 1),
      OrbitSpec(0.50f, 0.68f, 0.66f, 12.5f, 3),
    )
    return specs.map { spec ->
      val nx = (hub.nx + (spec.angleDeg / 360f - 0.5f) * spec.spread * 1.48f).coerceIn(0.02f, 0.98f)
      val ny = (hub.ny + spec.radial * 0.58f - spec.depth * 0.10f).coerceIn(0.03f, 0.97f)
      GraphNode(
        nx = nx,
        ny = ny,
        depth = spec.depth,
        radiusDp = spec.radiusDp,
        tintIndex = spec.paletteIdx % paletteSize,
      )
    }
  }

  private data class OrbitSpec(
    val angleDeg: Float,
    val radial: Float,
    val depth: Float,
    val radiusDp: Float,
    val paletteIdx: Int,
    val spread: Float = 0.96f,
  )

  private fun buildEdges(
    satellites: List<GraphNode>,
    hub: GraphNode,
  ): List<Triple<GraphNode, GraphNode, Float>> {
    val pairs = mutableListOf<Triple<GraphNode, GraphNode, Float>>()
    for (sat in satellites) {
      pairs += Triple(sat, hub, 1f)
    }
    val peerLinks = listOf(
      0 to 1, 1 to 2, 2 to 3, 3 to 4, 4 to 5, 5 to 6, 6 to 7,
      7 to 8, 8 to 9, 9 to 10, 0 to 4, 11 to 0,
    )
    for ((i, j) in peerLinks) {
      if (i < satellites.size && j < satellites.size) {
        pairs += Triple(satellites[i], satellites[j], 0.32f)
      }
    }
    return pairs
  }

  private fun project(node: GraphNode, width: Int, height: Int, density: Float): PointF =
    projectRaw(node.nx, node.ny, node.depth, width, height, density)

  private fun project(hub: GraphHub, width: Int, height: Int, density: Float): PointF =
    projectRaw(hub.nx, hub.ny, hub.depth, width, height, density)

  private fun projectRaw(
    nx: Float,
    ny: Float,
    depth: Float,
    width: Int,
    height: Int,
    density: Float,
  ): PointF {
    val isoSkew = 0.48f
    val spreadX = width * 1.40f
    val spreadY = height * 1.18f
    val cx = width * 0.56f
    val cy = height * 0.46f
    val xOff = (nx - 0.5f) * spreadX + (ny - 0.5f) * spreadX * isoSkew
    val yOff = (ny - 0.5f) * spreadY - depth * 56f * density
    return PointF(cx + xOff, cy + yOff)
  }

  private fun drawAmbientBackground(
    canvas: Canvas,
    width: Int,
    height: Int,
    palette: IntArray,
    isDark: Boolean,
  ) {
    val base = if (isDark) 0xFF0E1018.toInt() else 0xFFF5F7FC.toInt()
    canvas.drawColor(base)

    val blobs = listOf(
      NebulaBlob(0.58f, 0.38f, 0.78f, palette[0], if (isDark) 0.34f else 0.22f),
      NebulaBlob(0.90f, 0.20f, 0.55f, palette[1], if (isDark) 0.28f else 0.18f),
      NebulaBlob(0.08f, 0.68f, 0.50f, palette[2], if (isDark) 0.26f else 0.16f),
      NebulaBlob(0.74f, 0.82f, 0.48f, palette[4], if (isDark) 0.24f else 0.15f),
      NebulaBlob(0.26f, 0.12f, 0.40f, palette[6], if (isDark) 0.22f else 0.14f),
      NebulaBlob(0.44f, 0.50f, 0.42f, palette[8], if (isDark) 0.20f else 0.12f),
    )
    for (blob in blobs) {
      val cx = width * blob.nx
      val cy = height * blob.ny
      val radius = min(width, height) * blob.radiusScale
      val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = RadialGradient(
          cx,
          cy,
          radius,
          intArrayOf(
            withAlpha(blob.color, blob.alpha),
            withAlpha(blob.color, blob.alpha * 0.45f),
            Color.TRANSPARENT,
          ),
          floatArrayOf(0f, 0.55f, 1f),
          Shader.TileMode.CLAMP,
        )
      }
      canvas.drawCircle(cx, cy, radius, paint)
    }
  }

  private data class NebulaBlob(
    val nx: Float,
    val ny: Float,
    val radiusScale: Float,
    val color: Int,
    val alpha: Float,
  )

  private fun drawDepthPlane(
    canvas: Canvas,
    width: Int,
    height: Int,
    density: Float,
    palette: IntArray,
    isDark: Boolean,
  ) {
    val baseY = height * 0.94f
    for (i in 0 until 8) {
      val t = i / 7f
      val color = palette[(i + 1) % palette.size]
      val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = (1.0f + (1f - t) * 0.6f) * density
        this.color = withAlpha(color, if (isDark) 0.12f + (1f - t) * 0.06f else 0.08f + (1f - t) * 0.04f)
      }
      val x0 = width * (0.06f + t * 0.88f)
      canvas.drawLine(x0, baseY, x0 + width * 0.16f, baseY - height * 0.26f, gridPaint)
    }
    for (i in 0 until 6) {
      val t = i / 5f
      val color = palette[(i + 3) % palette.size]
      val gridPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 1.0f * density
        this.color = withAlpha(color, if (isDark) 0.10f else 0.07f)
      }
      val y = baseY - t * height * 0.22f
      canvas.drawLine(width * 0.04f, y, width * 0.96f, y, gridPaint)
    }
  }

  private fun drawHubAura(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    hubRadius: Float,
    palette: IntArray,
    isDark: Boolean,
  ) {
    val auraColors = intArrayOf(palette[0], palette[1], palette[4], palette[6])
    for (i in 4 downTo 1) {
      val r = hubRadius * (2.4f + i * 0.62f)
      val color = auraColors[(i - 1) % auraColors.size]
      val alpha = if (isDark) 0.16f + i * 0.10f else 0.11f + i * 0.07f
      val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = RadialGradient(
          cx,
          cy,
          r,
          intArrayOf(withAlpha(color, alpha), withAlpha(color, alpha * 0.5f), Color.TRANSPARENT),
          floatArrayOf(0f, 0.48f, 1f),
          Shader.TileMode.CLAMP,
        )
      }
      canvas.drawCircle(cx, cy, r, glow)
    }
  }

  private fun drawOrbitalGuides(
    canvas: Canvas,
    hubPt: PointF,
    hubRadius: Float,
    palette: IntArray,
    isDark: Boolean,
  ) {
    val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      strokeCap = Paint.Cap.ROUND
    }
    val radii = floatArrayOf(2.0f, 3.1f, 4.4f, 5.8f)
    val alphas = if (isDark) floatArrayOf(0.32f, 0.24f, 0.16f, 0.10f) else floatArrayOf(0.22f, 0.16f, 0.10f, 0.06f)
    for (i in radii.indices) {
      ringPaint.strokeWidth = hubRadius * 0.08f
      ringPaint.color = withAlpha(palette[(i + 1) % palette.size], alphas[i])
      canvas.drawCircle(hubPt.x, hubPt.y, hubRadius * radii[i], ringPaint)
    }
  }

  private fun drawArcEdge(
    canvas: Canvas,
    a: PointF,
    b: PointF,
    colorStart: Int,
    colorEnd: Int,
    strokeWidth: Float,
    alpha: Float,
    isDark: Boolean,
  ) {
    val path = Path().apply {
      moveTo(a.x, a.y)
      val midX = (a.x + b.x) * 0.5f
      val midY = (a.y + b.y) * 0.5f + strokeWidth * 1.1f
      quadTo(midX, midY, b.x, b.y)
    }
    val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      this.strokeWidth = strokeWidth * 2.6f
      strokeCap = Paint.Cap.ROUND
      color = withAlpha(blendColors(colorStart, colorEnd), alpha * (if (isDark) 0.38f else 0.28f))
    }
    canvas.drawPath(path, glow)
    val core = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      this.strokeWidth = strokeWidth
      strokeCap = Paint.Cap.ROUND
      shader = LinearGradient(
        a.x,
        a.y,
        b.x,
        b.y,
        withAlpha(colorStart, alpha),
        withAlpha(colorEnd, alpha * 0.92f),
        Shader.TileMode.CLAMP,
      )
    }
    canvas.drawPath(path, core)
  }

  private fun drawSoftVignette(canvas: Canvas, width: Int, height: Int, isDark: Boolean) {
    val edge = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        width * 0.56f,
        height * 0.44f,
        min(width, height) * 0.88f,
        intArrayOf(Color.TRANSPARENT, withAlpha(Color.BLACK, if (isDark) 0.12f else 0.07f)),
        floatArrayOf(0.52f, 1f),
        Shader.TileMode.CLAMP,
      )
    }
    canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), edge)
  }

  private fun drawNodeShadow(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    radius: Float,
    alpha: Float,
    isDark: Boolean,
  ) {
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      color = withAlpha(0xFF000000.toInt(), if (isDark) alpha else alpha * 0.75f)
    }
    canvas.drawOval(cx - radius, cy - radius * 0.38f, cx + radius, cy + radius * 0.38f, paint)
    canvas.drawOval(
      cx - radius * 0.7f,
      cy - radius * 0.22f,
      cx + radius * 0.7f,
      cy + radius * 0.22f,
      paint.apply { color = withAlpha(0xFF000000.toInt(), alpha * 0.55f) },
    )
  }

  private fun drawSatelliteGlow(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    radius: Float,
    color: Int,
    isDark: Boolean,
  ) {
    val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        cx,
        cy,
        radius * 2.2f,
        intArrayOf(withAlpha(color, if (isDark) 0.32f else 0.24f), Color.TRANSPARENT),
        floatArrayOf(0.35f, 1f),
        Shader.TileMode.CLAMP,
      )
    }
    canvas.drawCircle(cx, cy, radius * 2.2f, glow)
  }

  private fun drawSphereNode(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    radius: Float,
    color: Int,
    depth: Float,
    isDark: Boolean,
    isHub: Boolean,
  ) {
    val light = adjustHsv(color, saturationMul = 0.92f, valueMul = 1.30f)
    val core = adjustHsv(color, saturationMul = 1.12f, valueMul = if (isDark) 1.02f else 1.0f)
    val rim = adjustHsv(color, saturationMul = 1.15f, valueMul = if (isDark) 0.74f else 0.84f)
    val bodyAlpha = when {
      isHub -> 0.98f
      depth > 0.88f -> 0.62f
      else -> 0.72f + (1f - depth) * 0.26f
    }

    val body = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      shader = RadialGradient(
        cx - radius * 0.40f,
        cy - radius * 0.44f,
        radius * 1.55f,
        intArrayOf(
          withAlpha(light, bodyAlpha),
          withAlpha(core, bodyAlpha * 0.97f),
          withAlpha(rim, bodyAlpha * 0.92f),
        ),
        floatArrayOf(0f, 0.52f, 1f),
        Shader.TileMode.CLAMP,
      )
    }
    canvas.drawCircle(cx, cy, radius, body)

    val highlight = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      this.color = withAlpha(Color.WHITE, if (isDark) 0.48f else 0.62f)
    }
    canvas.drawCircle(
      cx - radius * 0.36f,
      cy - radius * 0.40f,
      radius * (if (isHub) 0.34f else 0.30f),
      highlight,
    )

    val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      strokeWidth = radius * 0.11f
      this.color = withAlpha(Color.WHITE, if (isDark) 0.22f else 0.30f)
    }
    canvas.drawCircle(cx, cy, radius * 0.96f, stroke)

    if (isHub) {
      val outerRing = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = radius * 0.13f
        this.color = withAlpha(color, if (isDark) 0.68f else 0.55f)
      }
      canvas.drawCircle(cx, cy, radius * 1.62f, outerRing)
      val midRing = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = radius * 0.07f
        this.color = withAlpha(Color.WHITE, if (isDark) 0.28f else 0.38f)
      }
      canvas.drawCircle(cx, cy, radius * 1.28f, midRing)
      val inner = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = RadialGradient(
          cx,
          cy,
          radius * 0.42f,
          intArrayOf(withAlpha(Color.WHITE, if (isDark) 0.82f else 0.92f), withAlpha(color, 0.58f)),
          floatArrayOf(0f, 1f),
          Shader.TileMode.CLAMP,
        )
      }
      canvas.drawCircle(cx, cy, radius * 0.38f, inner)
    }
  }

  private fun blendColors(a: Int, b: Int): Int =
    Color.rgb(
      (Color.red(a) + Color.red(b)) / 2,
      (Color.green(a) + Color.green(b)) / 2,
      (Color.blue(a) + Color.blue(b)) / 2,
    )

  private fun adjustHsv(color: Int, saturationMul: Float, valueMul: Float): Int {
    val hsv = FloatArray(3)
    Color.colorToHSV(color, hsv)
    hsv[1] = min(1f, hsv[1] * saturationMul)
    hsv[2] = min(1f, hsv[2] * valueMul)
    return Color.HSVToColor(Color.alpha(color), hsv)
  }

  private fun withAlpha(color: Int, alpha: Float): Int {
    val a = (alpha * 255f).toInt().coerceIn(0, 255)
    return (color and 0x00FFFFFF) or (a shl 24)
  }
}
