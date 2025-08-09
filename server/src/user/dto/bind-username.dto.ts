import { ApiProperty } from '@nestjs/swagger'
import { IsNotEmpty, IsString, Length } from 'class-validator'

export class BindUsernameDto {
  @ApiProperty({
    description: 'username',
    example: 'data-plane-user',
  })
  @IsString()
  @IsNotEmpty()
  @Length(3, 64)
  username: string
}
