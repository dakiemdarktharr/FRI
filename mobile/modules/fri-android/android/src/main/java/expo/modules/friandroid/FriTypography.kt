package expo.modules.friandroid

import androidx.compose.material3.Typography
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight

private val friFont = FontFamily(
  Font(R.font.be_vietnam_pro_regular, FontWeight.Normal),
  Font(R.font.be_vietnam_pro_semibold, FontWeight.SemiBold),
  Font(R.font.be_vietnam_pro_bold, FontWeight.Bold)
)
private val base = Typography()
val FriTypography = Typography(
  displayLarge=base.displayLarge.copy(fontFamily=friFont),
  displayMedium=base.displayMedium.copy(fontFamily=friFont),
  displaySmall=base.displaySmall.copy(fontFamily=friFont),
  headlineLarge=base.headlineLarge.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  headlineMedium=base.headlineMedium.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  headlineSmall=base.headlineSmall.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  titleLarge=base.titleLarge.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  titleMedium=base.titleMedium.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  titleSmall=base.titleSmall.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  bodyLarge=base.bodyLarge.copy(fontFamily=friFont),
  bodyMedium=base.bodyMedium.copy(fontFamily=friFont),
  bodySmall=base.bodySmall.copy(fontFamily=friFont),
  labelLarge=base.labelLarge.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  labelMedium=base.labelMedium.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold),
  labelSmall=base.labelSmall.copy(fontFamily=friFont,fontWeight=FontWeight.SemiBold)
)
