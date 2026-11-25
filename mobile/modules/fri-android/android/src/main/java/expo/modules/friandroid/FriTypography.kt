package expo.modules.friandroid

import androidx.compose.material3.Typography
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight

private val inter = FontFamily(
  Font(R.font.inter_regular, FontWeight.Normal),
  Font(R.font.inter_semibold, FontWeight.SemiBold),
  Font(R.font.inter_bold, FontWeight.Bold)
)
private val base = Typography()
val FriTypography = Typography(
  displayLarge=base.displayLarge.copy(fontFamily=inter),
  displayMedium=base.displayMedium.copy(fontFamily=inter),
  displaySmall=base.displaySmall.copy(fontFamily=inter),
  headlineLarge=base.headlineLarge.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  headlineMedium=base.headlineMedium.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  headlineSmall=base.headlineSmall.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  titleLarge=base.titleLarge.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  titleMedium=base.titleMedium.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  titleSmall=base.titleSmall.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  bodyLarge=base.bodyLarge.copy(fontFamily=inter),
  bodyMedium=base.bodyMedium.copy(fontFamily=inter),
  bodySmall=base.bodySmall.copy(fontFamily=inter),
  labelLarge=base.labelLarge.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  labelMedium=base.labelMedium.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold),
  labelSmall=base.labelSmall.copy(fontFamily=inter,fontWeight=FontWeight.SemiBold)
)
